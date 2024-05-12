import { type Prisma, Status } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { exclude, parseGenericError } from '@/utils'

const connections = new Map<string, WebSocket>()
const websocket: FastifyPluginCallback = (fastify, _, done) => {
	fastify.addHook('preParsing', authenticationHook)
	fastify.get('/', { websocket: true }, (socket, req) => {
		if (!req.authenticatedUser)
			return socket.close(1008, 'User is not authenticated')
		connections.set(req.authenticatedUser.name, socket)

		socket.on('message', async (msg) => {
			if (!req.authenticatedUser) return

			// TODO: handle JSON parsing error (if it's not a valid JSON string, it will crash the conneection)
			const message = JSON.parse(msg.toString()) as {
				id: string
				content: string
				receiver: string
				sender: string
				state: Status | undefined
			}

			message.sender = req.authenticatedUser.name

			// If message has no state, it's a new message (not a status update)
			if (!message.state) sendStatusUpdate(Status.SENT, message.id, socket)

			// Receiver is online
			if (connections.has(message.receiver)) {
				// if message has state (status update), send it to the receiver

				const receiver = connections.get(message.receiver)

				// if a message has a state, it's a status update
				message.state === undefined
					? receiver?.send(JSON.stringify(exclude(message, ['receiver'])))
					: sendStatusUpdate(Status.RECEIVED, message.id, receiver as WebSocket)
			} else {
				if (message.state) {
					// if message has state (status update), store it in the database
					// TODO: this crashes because apparently one of the IDs are not valid UUIDs. Need to investigate
					console.log(message)
					await fastify.prisma.messageStatus.create({
						data: {
							messageId: message.id,
							state: message.state.toUpperCase() as Status,
							senderId: message.sender,
						},
					})
					return
				}
				// Check if receiver exists
				const offlineReceiver = await fastify.prisma.user.findUnique({
					where: {
						name: message.receiver,
					},
				})

				if (!offlineReceiver)
					return socket.send(
						JSON.stringify({
							error: 'Receiver not found',
						}),
					)

				const pendingMessage = await fastify.prisma.pendingMessage.create({
					// add receiver id to the pending message
					data: {
						id: message.id,
						content: message.content,
						receiver: {
							connect: {
								name: message.receiver,
							},
						},
						sender: {
							connect: {
								id: req.authenticatedUser.id,
							},
						},
					},
				})

				await fastify.prisma.messageStatus.create({
					data: {
						messageId: pendingMessage.id,
						state: Status.RECEIVED,
						senderId: message.sender,
					},
				})

				sendStatusUpdate(Status.RECEIVED, message.id, socket)
				// TODO send push notification to the receiver
			}
		})

		socket.on('close', () => {
			if (!req.authenticatedUser) return
			connections.delete(req.authenticatedUser.name)
		})
	})

	fastify.setErrorHandler(async (error, request, reply) => {
		const apiError = parseGenericError(error)

		request.log.error(apiError.message)

		reply.code(apiError.statusCode)
	})

	done()
}

function sendStatusUpdate(
	Status: Status,
	messageId: string,
	socket: WebSocket,
) {
	const statusUpdate = {
		messageId,
		state: Status,
	}
	socket.send(JSON.stringify(statusUpdate))
}

export default websocket

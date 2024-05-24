import { Status } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { exclude, parseGenericError } from '@/utils'
import { initializeApp } from 'firebase-admin/app'
import {
	type Message as FirebaseMessage,
	getMessaging,
} from 'firebase-admin/messaging'

const connections = new Map<string, WebSocket>()
initializeApp()

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
				id: string // generated from the client
				content: string
				receiver: string // when it's a status update, it's usually the sender (receiver as in who will receive the message or update)
				state: Status | undefined // if it's defined, it's a status update
				sender: string
			}
			message.state = message.state?.toUpperCase() as Status
			message.sender = req.authenticatedUser.name

			// If message has no state, it's a new message (not a status update)
			if (!message.state) sendStatusUpdate(Status.SENT, message.id, socket)

			// Check if receiver exists
			const receiver = await fastify.prisma.user.findUnique({
				where: {
					name: message.receiver,
				},
			})
			if (!receiver)
				return socket.send(
					JSON.stringify({
						error: 'Receiver not found',
					}),
				)

			// Receiver is online
			if (connections.has(message.receiver)) {
				// if message has state (status update), send it to the receiver

				const receiverChannel = connections.get(message.receiver)

				// if a message has a state, it's a status update
				// TODO: real-time status updates do not work (read is not working because it sends to the wrong person, fix the logic)
				if (message.state) {
					sendStatusUpdate(
						message.state,
						message.id,
						receiverChannel as WebSocket,
					)
					return
				}

				receiverChannel?.send(JSON.stringify(exclude(message, ['receiver'])))
				sendStatusUpdate(Status.RECEIVED, message.id, socket)
			} else {
				if (message.state) {
					// if message has state (status update), store it in the database
					const senderId = (
						await fastify.prisma.user.findUnique({
							where: {
								name: message.receiver,
							},
							select: {
								id: true,
							},
						})
					)?.id

					if (senderId)
						await fastify.prisma.messageStatus.create({
							data: {
								messageId: message.id,
								state: message.state,
								senderId: senderId,
							},
						})

					return
				}
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
						senderId: req.authenticatedUser.id,
					},
				})

				sendStatusUpdate(Status.RECEIVED, message.id, socket)
			}
			if (!receiver.notificationID) return
			console.log(
				`Sending notification to ${receiver.notificationID} (${receiver.name})`,
			)
			const firebaseMessage: FirebaseMessage = {
				token: receiver.notificationID,
				notification: {
					title: `${req.authenticatedUser.name}`,
					body: 'New message',
				},
			}
			await getMessaging().send(firebaseMessage)
			console.log('Notification sent')
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

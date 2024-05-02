import type { Prisma } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { exclude, parseGenericError } from '@/utils'
import { PrismaClient } from '@prisma/client/extension'

enum MessageStatus {
	SENT = 'sent',
	DELIVERED = 'delivered',
	READ = 'read',
	ERROR = 'error',
}

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
			}

			message.sender = req.authenticatedUser.name

			socket.send(
				JSON.stringify({
					status: MessageStatus.SENT,
					message: exclude(message, ['sender']),
				}),
			)

			console.log('Message received:', message)
			if (connections.has(message.receiver)) {
				const receiver = connections.get(message.receiver)
				receiver?.send(JSON.stringify(exclude(message, ['receiver'])))
				socket.send(
					JSON.stringify({
						status: MessageStatus.DELIVERED,
						message: exclude(message, ['sender']),
					}),
				)
			} else {
				// Check if receiver exists
				const offlineReceiver = await fastify.prisma.user.findUnique({
					where: {
						name: message.receiver,
					},
				})

				if (!offlineReceiver)
					return socket.send(
						JSON.stringify({
							status: MessageStatus.ERROR,
							error: 'Receiver not found',
						}),
					)

				fastify.prisma.pendingMessage
					.create({
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
					.then((storedPendingMessage) => {
						// TODO send push notification to the receiver. If successful, update the message status to delivered for the sender.
					})
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

export default websocket

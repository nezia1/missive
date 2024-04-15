import type { Prisma } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { exclude, parseGenericError } from '@/utils'

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

		connections.set(req.authenticatedUser.id, socket)

		socket.on('message', async (msg) => {
			if (!req.authenticatedUser) return

			// TODO: handle JSON parsing error (if it's not a valid JSON string, it will crash the conneection)
			const message = JSON.parse(
				msg.toString(),
			) as Prisma.PendingMessageCreateManyInput

			// Create a pending message
			const pendingMessage: Prisma.PendingMessageCreateManyInput = {
				content: message.content,
				receiverId: message.receiverId,
				senderId: req.authenticatedUser.id,
			}

			socket.send(
				JSON.stringify({
					status: MessageStatus.SENT,
					message: exclude(pendingMessage, ['senderId']),
				}),
			)

			if (connections.has(message.receiverId)) {
				const receiver = connections.get(message.receiverId)
				receiver?.send(JSON.stringify(exclude(pendingMessage, ['receiverId'])))
				socket.send(
					JSON.stringify({
						status: MessageStatus.DELIVERED,
						message: exclude(pendingMessage, ['senderId']),
					}),
				)
			} else {
				// Check if receiver exists
				const offlineReceiver = await fastify.prisma.user.findUnique({
					where: {
						id: message.receiverId,
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
						data: pendingMessage,
					})
					.then((storedPendingMessage) => {
						// TODO send push notification to the receiver. If successful, update the message status to delivered for the sender.
					})
			}
		})

		socket.on('close', () => {
			if (!req.authenticatedUser) return
			connections.delete(req.authenticatedUser.id)
		})
	})

	fastify.setErrorHandler(async (error, request, reply) => {
		const apiError = parseGenericError(error)

		request.log.error(apiError.message)

		return reply
			.code(apiError.statusCode)
			.send({ error: apiError.responseMessage })
	})

	done()
}

export default websocket

import type { FastifyPluginCallback } from 'fastify'

import { AuthorizationError } from '@/errors'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import { exclude, parseGenericError } from '@/utils'

import type { APIReply, MessageParams } from '@/globals'

const messages: FastifyPluginCallback = (fastify, _, done) => {
	fastify.route<{ Reply: APIReply; Params: MessageParams }>({
		method: 'GET',
		url: '/:name/messages',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.MESSAGES_READ]),
		],
		handler: async (request, reply) => {
			if (request.params.name !== request.authenticatedUser?.name)
				throw new AuthorizationError('You can only read your own messages')

			const messages = await fastify.prisma.pendingMessage.findMany({
				where: { receiverId: request.authenticatedUser.id },
				include: {
					sender: {
						select: { name: true },
					},
				},
			})
			const messagesWithoutId = messages.map((message) =>
				exclude(message, ['receiverId']),
			)
			reply.status(200).send({ data: { messages: messagesWithoutId } })

			await fastify.prisma.pendingMessage.deleteMany({
				where: { receiverId: request.authenticatedUser.id },
			})
		},
	})

	fastify.route<{ Reply: APIReply; Params: MessageParams }>({
		method: 'GET',
		url: '/:name/messages/status',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.MESSAGES_READ]),
		],
		handler: async (request, reply) => {
			if (request.params.name !== request.authenticatedUser?.name)
				throw new AuthorizationError('You can only read your own messages')

			// fetch the status of the messages sent by the authenticated user
			const statuses = await fastify.prisma.messageStatus.findMany({
				where: { senderId: request.authenticatedUser.id },
				select: { state: true, messageId: true },
			})

			reply.status(200).send({ data: { statuses } })
		},
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

export default messages

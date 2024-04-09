import type { FastifyPluginCallback } from 'fastify'

import { AuthorizationError } from '@/errors'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import { exclude, parseGenericError } from '@/utils'

import type { APIReply, UserParams } from '@/globals'

const messages: FastifyPluginCallback = (fastify, _, done) => {
	fastify.route<{ Reply: APIReply; Params: UserParams }>({
		method: 'GET',
		url: '/:id/messages',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.MESSAGES_READ]),
		],
		handler: async (request, reply) => {
			if (request.params.id !== request.authenticatedUser?.id)
				throw new AuthorizationError('You can only read your own messages')

			const messages = await fastify.prisma.pendingMessage.findMany({
				where: { receiverId: request.params.id },
			})
			const messagesWithoutId = messages.map((message) =>
				exclude(message, ['receiverId']),
			)
			reply.status(200).send({ data: { messagesWithoutId } })
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

import type { Prisma } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { AuthorizationError } from '@/errors'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import {
	exclude,
	generateRandomBase32String,
	loadKeys,
	parseGenericError,
} from '@/utils'

import type { APIReply, UserParams } from '@/globals'

if (!process.env.API_KEY) {
	console.error('API_KEY is not defined')
	process.exit(1)
}

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

	fastify.route<{
		Body: Prisma.PendingMessageCreateManyInput[]
		Params: UserParams
	}>({
		method: 'POST',
		url: '/:id/messages',
		preParsing: authenticationHook,
		handler: async (request, reply) => {
			const messagesWithReceiverId = request.body.map((message) => ({
				...message,
				receiverId: request.params.id,
			}))

			console.log(messagesWithReceiverId)
			await fastify.prisma.pendingMessage.createMany({
				data: messagesWithReceiverId,
			})

			reply.status(201).send()
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

import { type Prisma, PrismaClient } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { parseGenericError } from '@/utils'

const prisma = new PrismaClient()

interface UserMessage {
	userId: string
	content: string
}
const websocket: FastifyPluginCallback = (fastify, _, done) => {
	fastify.addHook('preParsing', authenticationHook)
	fastify.get('/', { websocket: true }, (socket, req) => {
		socket.on('message', (msg) => {
			// TODO: handle JSON parsing error (if it's not a valid JSON string, it will crash the conneection)
			const message = JSON.parse(msg.toString()) as UserMessage
			socket.send(`WEBSOCKET IS WORKING 🎉!  User sent ${message.content}`)
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

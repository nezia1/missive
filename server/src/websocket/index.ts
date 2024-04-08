import { type Prisma, PrismaClient } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

import { authenticationHook } from '@/hooks'
import { parseGenericError } from '@/utils'

import { AuthenticationStrategies } from '@/auth-strategies'

const prisma = new PrismaClient()

const websocket: FastifyPluginCallback = (fastify, _, done) => {
	fastify.addHook('preParsing', authenticationHook)
	fastify.get('/', { websocket: true }, (socket, req) => {
		socket.on('message', (msg) => {
			socket.send('WEBSOCKET IS WORKING! 🎉')
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

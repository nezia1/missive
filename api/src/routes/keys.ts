import type { APIReply, UserParams } from '@/globals'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import { PrismaClient } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

const prisma = new PrismaClient()
const secret = new TextEncoder().encode(process.env.JWT_SECRET)

const keys: FastifyPluginCallback = (fastify, _, done) => {
	fastify.route<{ Reply: APIReply; Params: UserParams }>({
		method: 'GET',
		url: '/:id/keys',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.KEYS_READ]),
		],
		handler: async (request, reply) => {
			const keys = await prisma.preKey.findMany({
				where: {
					userId: request.params.id,
				},
			})
			reply.status(200).send({ data: { keys } })
		},
	})
	done()
}

export default keys

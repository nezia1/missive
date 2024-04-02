import type { APIReply, UserParams } from '@/globals'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import { type Prisma, PrismaClient } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

const prisma = new PrismaClient()
const secret = new TextEncoder().encode(process.env.JWT_SECRET)

const keys: FastifyPluginCallback = (fastify, _, done) => {
	// Gets the first pre key for a user, as well as the signed pre key
	fastify.route<{ Reply: APIReply; Params: UserParams }>({
		method: 'GET',
		url: '/:id/keys',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.KEYS_READ]),
		],
		handler: async (request, reply) => {
			const preKey = await prisma.preKey.findFirst({
				where: {
					userId: request.params.id,
				},
			})

			// TODO: handle case when preKey is not found (we are just going to not delete and return null for now to avoid it crashing)
			if (preKey)
				await prisma.preKey.delete({
					where: {
						id: preKey?.id,
					},
				})

			const signedPreKey = await prisma.signedPreKey.findFirst({
				where: { userId: request.params.id },
			})

			reply.status(200).send({ data: { preKey, signedPreKey } })
		},
	})

	fastify.route<{
		Body: Prisma.PreKeyCreateManyInput[]
		Reply: APIReply
		Params: UserParams
	}>({
		method: 'POST',
		url: '/:id/keys/pre',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.KEYS_WRITE]),
		],
		handler: async (request, reply) => {
			await prisma.preKey.createMany({ data: request.body })
			reply.status(204).send()
		},
	})

	done()
}

export default keys

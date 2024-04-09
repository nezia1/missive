import type { APIReply, UserParams } from '@/globals'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import type { Prisma } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

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
			const oneTimePreKey = await fastify.prisma.oneTimePreKey.findFirst({
				where: {
					userId: request.params.id,
				},
			})

			// TODO: handle case when oneTimePreKey is not found (we are just going to not delete and return null for now to avoid it crashing). Ideally, we should have a last resort pre key that is always present
			if (oneTimePreKey)
				await fastify.prisma.oneTimePreKey.delete({
					where: {
						id: oneTimePreKey?.id,
					},
				})

			const signedPreKey = await fastify.prisma.signedPreKey.findFirst({
				where: { userId: request.params.id },
			})

			reply.status(200).send({ data: { oneTimePreKey, signedPreKey } })
		},
	})

	fastify.route<{
		Body: {
			oneTimePreKeys: Prisma.OneTimePreKeyCreateManyInput[]
			signedPreKey?: Prisma.SignedPreKeyCreateInput
		}
		Reply: APIReply
		Params: UserParams
	}>({
		method: 'POST',
		url: '/:id/keys',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.KEYS_WRITE]),
		],
		handler: async (request, reply) => {
			await fastify.prisma.oneTimePreKey.createMany({
				data: request.body.oneTimePreKeys,
			})

			if (request.body.signedPreKey)
				await fastify.prisma.signedPreKey.create({
					data: request.body.signedPreKey,
				})

			reply.status(204).send()
		},
	})

	done()
}

export default keys

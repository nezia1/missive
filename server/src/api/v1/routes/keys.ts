/**
 * @file Contains the API routes for public key management.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

import type { APIReply } from '@/globals'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import type { Prisma } from '@prisma/client'
import type { FastifyPluginCallback } from 'fastify'

/**
 * Contains the API routes for public key management.
 */
const keys: FastifyPluginCallback = (fastify, _, done) => {
	// Gets the first pre key for a user, as well as the signed pre key
	fastify.route<{ Reply: APIReply; Params: { name: string } }>({
		method: 'GET',
		url: '/:name/keys',
		preParsing: [
			authenticationHook(),
			authorizationHook([Permissions.KEYS_READ]),
		],
		handler: async (request, reply) => {
			const oneTimePreKey = await fastify.prisma.oneTimePreKey.findFirst({
				where: {
					user: { name: request.params.name },
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
				where: { user: { name: request.params.name } },
			})

			const user = await fastify.prisma.user.findUniqueOrThrow({
				where: { name: request.params.name },
			})

			reply.status(200).send({
				data: {
					oneTimePreKey,
					signedPreKey,
					identityKey: user.identityKey,
					registrationId: user.registrationId,
				},
			})
		},
	})

	fastify.route<{
		Body: {
			preKeys: Prisma.OneTimePreKeyCreateManyInput[]
			signedPreKey?: Prisma.SignedPreKeyCreateWithoutUserInput
			identityKey?: string
			registrationId?: number
		}
		Reply: APIReply
		Params: { name: string }
	}>({
		method: 'POST',
		url: '/:name/keys',
		preParsing: [
			authenticationHook(),
			authorizationHook([Permissions.KEYS_WRITE]),
		],
		handler: async (request, reply) => {
			await fastify.prisma.oneTimePreKey.createMany({
				data: request.body.preKeys.map((preKey) => ({
					...preKey,
					userId: request.authenticatedUser?.id || '', // really ugly hack
				})),
			})

			if (request.body.signedPreKey)
				await fastify.prisma.signedPreKey.create({
					data: {
						...request.body.signedPreKey,
						userId: request.authenticatedUser?.id || '', // really ugly hack
					},
				})

			if (request.body.identityKey && request.body.registrationId)
				await fastify.prisma.user.update({
					where: { name: request.params.name },
					data: {
						identityKey: request.body.identityKey,
						registrationId: request.body.registrationId,
					},
				})

			reply.status(204).send()
		},
	})

	done()
}

export default keys

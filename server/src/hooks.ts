/**
 * @file This file contains all the hooks (Fastify middlewares) that are used throughout the application. Hooks are used to handle authentication and authorization.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

import { AuthenticationError, AuthorizationError } from '@/errors'
import { verifyAndDecodeScopedJWT } from '@/jwt'
import type { Permissions } from '@/permissions'
import prisma from '@/prisma'
import { loadKeys } from '@/utils'
import type { User } from '@prisma/client'
import type { FastifyReply, FastifyRequest } from 'fastify'
import { importSPKI } from 'jose'
import { JWTInvalid } from 'jose/errors'

const { publicKeyPem } = loadKeys()

const publicKey = await importSPKI(publicKeyPem, 'P256')

// This is needed to augment the FastifyRequest type and add the authenticatedUser property
declare module 'fastify' {
	interface FastifyRequest {
		authenticatedUser?: User & { permissions?: string[] }
	}
}

/**
 * Verifies the access token and injects the authenticated user in the request. This function needs to be curried so that we can abstract the verification and decoding process, for testing purposes (we cannot stub a function that is not passed as an argument)
 * @param {Function} verifyAndDecode - The function to use to verify and decode the access token
 * @returns {Promise<void>}
 * @example
 * import { authenticationHook } from './hooks'
 * app.addHook('onRequest', authenticationHook) // Global hook
 * @example
 * import { authenticationHook } from './hooks'
 * import { verifyAndDecodeScopedJWT } from './jwt'
 * fastify.route({
 *   method: 'GET',
 *   url: '/',
 * 	preParsing: [authenticationHook(verifyAndDecodeJwt)], // Route hook
 * 	handler: async (request, reply) => {
 * 		reply.send({ authenticatedUser: request.authenticatedUser }) // Authenticated user is injected in the request
 * 	},
 * })
 */
export function authenticationHook(verifyAndDecode = verifyAndDecodeScopedJWT) {
	return async (request: FastifyRequest, reply: FastifyReply) => {
		const accessToken = request.headers.authorization?.split(' ')[1]

		if (!accessToken) throw new JWTInvalid('Missing access token')

		// Get access token payload and check if it matches a user (jwtVerify throws an error if the token is invalid for any reason)
		const payload = await verifyAndDecode(accessToken, publicKey)
		const user = await prisma.user.findUniqueOrThrow({
			where: { id: payload.sub },
		})
		// Inject the authenticated user ID in the request
		request.authenticatedUser = user

		if (!payload.scope)
			throw new AuthorizationError(
				'Token used does not have any permissions (likely a refresh token)',
			)

		request.authenticatedUser.permissions = payload.scope
	}
}

/**
 * Checks if the user has the required permissions. This is a function that returns a Fastify hook.
 *
 * This is necessary because Fastify hooks are functions with a specific signature, with request and reply, so we can't pass the permissionsRequired array directly, hence why a curried function is needed.
 * @param {Permissions[]} permissionsRequired - The required permissions
 * @returns {FastifyPluginCallback} - The Fastify hook
 * @example
 * import { authorizationHook } from './hooks'
 * app.addHook('preHandler', authorizationHook([Permissions.MESSAGES_READ])) // Global hook
 * @example
 * import { authorizationHook } from './hooks'
 * fastify.route({
 *   method: 'GET',
 *   url: '/',
 * 	preHandler: [authorizationHook([Permissions.MESSAGES_READ])], // Route hook
 * 	handler: async (request, reply) => {
 * 		reply.send({ authenticatedUser: request.authenticatedUser }) // Authenticated user is injected in the request
 * })
 */
export function authorizationHook(permissionsRequired: Permissions[]) {
	return async (request: FastifyRequest, reply: FastifyReply) => {
		if (!request.authenticatedUser)
			throw new AuthenticationError('User not authenticated')

		// Check if the user has the required permissions
		if (
			!permissionsRequired.every((permission) =>
				request.authenticatedUser?.permissions?.includes(permission),
			)
		) {
			throw new AuthorizationError(
				`You don't have the required permissions to access this resource (need ${permissionsRequired.join()})`,
			)
		}
	}
}

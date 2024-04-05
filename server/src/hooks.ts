import { AuthenticationStrategies } from '@/auth-strategies'
import { AuthenticationError, AuthorizationError } from '@/errors'
import { verifyAndDecodeJWT } from '@/jwt'
import type { Permissions } from '@/permissions'
import { loadKeys } from '@/utils'
import { PrismaClient, type User } from '@prisma/client'
import type { FastifyReply, FastifyRequest } from 'fastify'
import { importSPKI } from 'jose'
import { JWTInvalid } from 'jose/errors'

const prisma = new PrismaClient()

const { publicKeyPem } = loadKeys()

const publicKey = await importSPKI(publicKeyPem, 'P256')

// This is needed to augment the FastifyRequest type and add the authenticatedUser property
declare module 'fastify' {
	interface FastifyRequest {
		authenticatedUser?: User & { permissions?: string[] }
	}
}

// This needs to be curried to be able to pass the authenticationStrategy (Fastify hooks are functions with a specific signature, with request and reply, so we can't pass the authenticationStrategy directly)
export function authenticationHook(
	authenticationStrategy: AuthenticationStrategies,
) {
	return async (request: FastifyRequest, reply: FastifyReply) => {
		switch (authenticationStrategy) {
			case AuthenticationStrategies.BEARER: {
				// Get access token from Authorization header
				const accessToken = request.headers.authorization?.split(' ')[1]

				if (!accessToken) throw new JWTInvalid('Missing access token')

				// Get access token payload and check if it matches a user (jwtVerify throws an error if the token is invalid for any reason)
				const payload = await verifyAndDecodeJWT(accessToken, publicKey)

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
				break
			}
			case AuthenticationStrategies.API_KEY: {
				// Get API key from headers
				const apiKey = request.headers['x-api-key']
				// Check if the API key is valid
				if (!apiKey) throw new AuthenticationError('Missing API key')
				if (apiKey !== process.env.API_KEY)
					throw new AuthenticationError('Invalid API key')
				break
			}

			default:
				break
		}
	}
}

// This needs to be curried to be able to pass the permissionsRequired array (Fastify hooks are functions with a specific signature, with request and reply, so we can't pass the permissionsRequired array directly)
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

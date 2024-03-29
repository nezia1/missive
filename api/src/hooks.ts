import { PrismaClient, type User } from '@prisma/client'
import type { FastifyReply, FastifyRequest } from 'fastify'
import { jwtVerify } from 'jose'
import { JWTInvalid } from 'jose/errors'

import { AuthenticationError, AuthorizationError } from './errors'
import { verifyAndDecodeJWT } from './jwt'

const prisma = new PrismaClient()

if (process.env.JWT_SECRET === null) {
	console.error('JWT_SECRET is not defined')
	process.exit(1)
}

const secret = new TextEncoder().encode(process.env.JWT_SECRET)

// This is needed to augment the FastifyRequest type and add the authenticatedUser property
declare module 'fastify' {
	interface FastifyRequest {
		authenticatedUser?: User & { permissions?: string[] }
	}
}

export async function authenticationHook(
	request: FastifyRequest,
	reply: FastifyReply,
): Promise<void> {
	// Get access token from Authorization header
	const accessToken = request.headers.authorization?.split(' ')[1]

	if (!accessToken) throw new JWTInvalid('Missing access token')

	// Get access token payload and check if it matches a user (jwtVerify throws an error if the token is invalid for any reason)
	const payload = await verifyAndDecodeJWT(accessToken, secret)

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

// This needs to be curried to be able to pass the permissionsRequired array (Fastify hooks are functions with a specific signature, with request and reply, so we can't pass the permissionsRequired array directly)
export function authorizationHook(permissionsRequired: string[]) {
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

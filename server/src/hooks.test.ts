import prisma from '@/__mocks__/prisma'
import app from '@/app'
import { sampleUsers } from '@/constants'
import type * as jwt from '@/jwt'
import { parseGenericError } from '@/utils'
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library'
import type { KeyLike } from 'jose'
import { JWTInvalid } from 'jose/errors'
import { type Mock, beforeAll, describe, expect, it, vi } from 'vitest'
import { authenticationHook, authorizationHook } from './hooks'
import { Permissions } from './permissions'

const sampleUser = sampleUsers[0]
let mockVerifyAndDecodeScopedJWT: Mock<
	[string, KeyLike],
	Promise<jwt.ScopedJWTPayload>
>
beforeAll(() => {
	vi.mock('@/prisma')
	mockVerifyAndDecodeScopedJWT = vi.fn()
	app.route({
		method: 'GET',
		url: '/test-authentication',
		preParsing: [authenticationHook(mockVerifyAndDecodeScopedJWT)],
		handler: async (request, reply) => {
			reply.send({ message: 'authenticated' })
		},
	})

	app.route({
		method: 'GET',
		url: '/test-authorization',
		preParsing: [
			authenticationHook(mockVerifyAndDecodeScopedJWT),
			authorizationHook([Permissions.MESSAGES_READ, Permissions.PROFILE_READ]),
		],
		handler: async (request, reply) => {
			reply.send({ message: 'authorized' })
		},
	})

	app.setErrorHandler(async (error, request, reply) => {
		const apiError = parseGenericError(error)

		request.log.error(apiError.message)

		return reply
			.code(apiError.statusCode)
			.send({ error: apiError.responseMessage })
	})
})

describe('authenticationHook', () => {
	it('should have a 401 UNAUTHORIZED status code if there is no access token', async () => {
		mockVerifyAndDecodeScopedJWT.mockRejectedValueOnce(new JWTInvalid()) // invalid token / missing token exception
		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
		})
		expect(response.statusCode).toBe(401)
	})

	it('should have a 401 UNAUTHORIZED status code if the access token is invalid', async () => {
		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
			headers: {
				Authorization: 'Bearer invalid-token',
			},
		})
		expect(response.statusCode).toBe(401)
	})

	it('should have a 401 UNAUTHORIZED status code if the access token is valid but the user does not exist', async () => {
		mockVerifyAndDecodeScopedJWT.mockResolvedValueOnce({
			sub: sampleUser.id,
			scope: [Permissions.KEYS_READ],
		})

		prisma.user.findUniqueOrThrow.mockRejectedValueOnce(
			new PrismaClientKnownRequestError('User not found', {
				code: 'P2025',
				clientVersion: 'version',
			}),
		)

		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
			headers: {
				Authorization: 'Bearer valid-token',
			},
		})
		expect(response.statusCode).toBe(404)
	})

	it('should have a 200 OK status code if the access token is valid and the user exists', async () => {
		mockVerifyAndDecodeScopedJWT.mockResolvedValueOnce({
			sub: sampleUser.id,
			scope: [Permissions.KEYS_READ],
		})

		prisma.user.findUniqueOrThrow.mockResolvedValueOnce(sampleUser)

		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
			headers: {
				Authorization: 'Bearer valid-token',
			},
		})
		expect(response.statusCode).toBe(200)
	})
})

describe('authorizationHook', () => {
	it('should have a 403 FORBIDDEN status code if the user does not have the required permissions', async () => {
		prisma.user.findUniqueOrThrow.mockResolvedValue(sampleUser)
		mockVerifyAndDecodeScopedJWT.mockResolvedValue({
			sub: sampleUser.id,
			scope: [Permissions.PROFILE_WRITE],
		})

		const response = await app.inject({
			method: 'GET',
			url: '/test-authorization',
			headers: {
				Authorization: 'Bearer valid-token',
			},
		})
		expect(response.statusCode).toBe(403)
	})
	it('should have a 403 FORBIDDEN status code if the user has not all the required permissions', async () => {
		prisma.user.findUniqueOrThrow.mockResolvedValue(sampleUser)
		mockVerifyAndDecodeScopedJWT.mockResolvedValue({
			sub: sampleUser.id,
			scope: [Permissions.MESSAGES_READ],
		})

		const response = await app.inject({
			method: 'GET',
			url: '/test-authorization',
			headers: {
				Authorization: 'Bearer valid-token',
			},
		})
		expect(response.statusCode).toBe(403)
	})

	it('should have a 200 OK status code if the user has all the required permissions', async () => {
		prisma.user.findUniqueOrThrow.mockResolvedValue(sampleUser)
		mockVerifyAndDecodeScopedJWT.mockResolvedValue({
			sub: sampleUser.id,
			scope: [Permissions.MESSAGES_READ, Permissions.PROFILE_READ],
		})
	})
})

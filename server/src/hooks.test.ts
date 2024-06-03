import prisma from '@/__mocks__/prisma'
import app from '@/app'
import { sampleUsers } from '@/constants'
import type * as jwt from '@/jwt'
import { loadKeys, parseGenericError } from '@/utils'
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library'
import type { KeyLike } from 'jose'
import { JWTInvalid } from 'jose/errors'
import { type Mock, beforeAll, describe, expect, it, vi } from 'vitest'
import { authenticationHook } from './hooks'
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
			reply.send({ message: 'authenticated ' })
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
	it('should set a route status code to 401 if there is no access token', async () => {
		mockVerifyAndDecodeScopedJWT.mockRejectedValueOnce(new JWTInvalid()) // invalid token / missing token exception
		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
		})
		expect(response.statusCode).toBe(401)
	})

	it('should set a route status code to 401 if the access token is invalid', async () => {
		const response = await app.inject({
			method: 'GET',
			url: '/test-authentication',
			headers: {
				Authorization: 'Bearer invalid-token',
			},
		})
		expect(response.statusCode).toBe(401)
	})
	it('should set a route status code to 200 if the access token is valid', async () => {
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

	it('should set a route status code to 401 if the access token is valid but the user does not exist', async () => {
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
})

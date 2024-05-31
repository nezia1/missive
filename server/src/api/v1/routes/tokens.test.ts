import prisma from '@/__mocks__/prisma'
import app from '@/app'
import { sampleUsers } from '@/constants'
import { loadKeys } from '@/utils'
import * as argon2 from 'argon2'
import { importSPKI, jwtVerify } from 'jose'
import type { Response } from 'light-my-request'
import { beforeAll, describe, expect, it, vi } from 'vitest'

const sampleUser = sampleUsers[0]

let successfulResponse: Response
let successfulResponseWithTOTP: Response
let unsuccessfulResponse: Response
let successfullyRefreshedTokenResponse: Response
let accessToken: string
let isAccessTokenValid: boolean

beforeAll(async () => {
	// Setup prisma mocks
	vi.mock('@/prisma')
	prisma.user.findUnique.mockResolvedValue({
		...sampleUser,
		password: await argon2.hash(sampleUser.password),
	})
	prisma.user.findUniqueOrThrow.mockResolvedValue(sampleUser)

	successfulResponse = await app.inject({
		method: 'POST',
		url: '/api/v1/tokens',
		payload: {
			name: sampleUser.name,
			password: sampleUser.password,
		},
	})

	unsuccessfulResponse = await app.inject({
		method: 'POST',
		url: '/api/v1/tokens',
		payload: {
			name: 'nonexistent',
			password: 'nonexistent',
		},
	})

	const { publicKeyPem } = loadKeys()
	const publicKey = await importSPKI(publicKeyPem, 'P256')

	successfullyRefreshedTokenResponse = await app.inject({
		method: 'PUT',
		url: '/api/v1/tokens',
		cookies: {
			refreshToken: successfulResponse.cookies[0].value,
		},
	})
	accessToken = successfullyRefreshedTokenResponse.json().data.accessToken

	try {
		await jwtVerify(accessToken, publicKey)
		isAccessTokenValid = true
	} catch {
		isAccessTokenValid = false
	}
})

describe('POST /v1/tokens', () => {
	it('should have a 201 CREATED status code on successful login', () => {
		expect(successfulResponse.statusCode).toBe(201)
	})

	it('should have a 401 UNAUTHORIZED status code on login using wrong credentials', () => {
		expect(unsuccessfulResponse.statusCode).toBe(401)
	})
})

describe('PUT /api/v1/tokens', () => {
	it('should respond with a valid access token', () => {
		expect(isAccessTokenValid).toBe(true)
	})
})

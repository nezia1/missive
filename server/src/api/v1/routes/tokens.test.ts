import assert from 'node:assert'
import { describe, it } from 'node:test'
import app from '@/app'
import { sampleUsers } from '@/constants'
import { loadKeys } from '@/utils'
import { importSPKI, jwtVerify } from 'jose'

const userWithTOTP = sampleUsers[0]
const userWithoutTOTP = sampleUsers[1]

const successfulResponseWithoutTOTP = await app.inject({
	method: 'POST',
	url: '/api/v1/tokens',
	payload: {
		name: userWithoutTOTP.name,
		password: userWithoutTOTP.password,
	},
})

describe('POST /v1/tokens', async () => {
	const successfulResponseWithTOTP = await app.inject({
		method: 'POST',
		url: '/api/v1/tokens',
		payload: {
			name: userWithTOTP.name,
			password: userWithTOTP.password,
		},
	})

	const unsuccessfulResponse = await app.inject({
		method: 'POST',
		url: '/api/v1/tokens',
		payload: {
			name: 'nonexistent',
			password: 'nonexistent',
		},
	})

	it('should have a 201 CREATED status code on successful login', () => {
		assert.strictEqual(successfulResponseWithoutTOTP.statusCode, 201)
	})

	it('should respond with status: totp_required field when using TOTP', () => {
		assert.strictEqual(
			successfulResponseWithTOTP.json().data.status,
			'totp_required',
			'should respond with status: totp_required field when using TOTP',
		)
	})

	it('should have a 401 UNAUTHORIZED status code on login using wrong credentials', () => {
		assert.strictEqual(unsuccessfulResponse.statusCode, 401)
	})
})

describe('PUT /api/v1/tokens', async () => {
	const { publicKeyPem } = loadKeys()
	const publicKey = await importSPKI(publicKeyPem, 'P256')

	const successfullyRefreshedTokenResponse = await app.inject({
		method: 'PUT',
		url: '/api/v1/tokens',
		cookies: {
			refreshToken: successfulResponseWithoutTOTP.cookies[0].value,
		},
	})
	const accessToken = successfullyRefreshedTokenResponse.json().data.accessToken

	let isAccessTokenValid: boolean
	try {
		await jwtVerify(accessToken, publicKey)
		isAccessTokenValid = true
	} catch {
		isAccessTokenValid = false
	}

	it('should respond with a valid access token', () => {
		assert.strictEqual(isAccessTokenValid, true)
	})
})
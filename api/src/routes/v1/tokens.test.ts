import assert from 'node:assert'
import { describe, it } from 'node:test'
import app from '@/app'
import { sampleUsers } from '@/constants'
import { jwtVerify } from 'jose'

const userWithTOTP = sampleUsers[0]
const userWithoutTOTP = sampleUsers[1]

const successfulResponseWithoutTOTP = await app.inject({
	method: 'POST',
	url: '/tokens',
	payload: {
		name: userWithoutTOTP.name,
		password: userWithoutTOTP.password,
	},
})

describe('POST /tokens', async () => {
	const successfulResponseWithTOTP = await app.inject({
		method: 'POST',
		url: '/tokens',
		payload: {
			name: userWithTOTP.name,
			password: userWithTOTP.password,
		},
	})

	const unsuccessfulResponse = await app.inject({
		method: 'POST',
		url: '/tokens',
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

describe('PUT /tokens', async () => {
	const secret = new TextEncoder().encode(process.env.JWT_SECRET)

	const successfullyRefreshedTokenResponse = await app.inject({
		method: 'PUT',
		url: '/tokens',
		cookies: {
			refreshToken: successfulResponseWithoutTOTP.cookies[0].value,
		},
	})

	const accessToken = successfullyRefreshedTokenResponse.json().data.accessToken

	let isAccessTokenValid: boolean
	try {
		await jwtVerify(accessToken, secret)
		isAccessTokenValid = true
	} catch {
		isAccessTokenValid = false
	}

	it('should respond with a valid access token', () => {
		assert.strictEqual(isAccessTokenValid, true)
	})
})

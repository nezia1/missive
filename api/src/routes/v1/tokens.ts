import { type Prisma, PrismaClient } from '@prisma/client'
import * as argon2 from 'argon2'
import type { FastifyPluginCallback } from 'fastify'
import { SignJWT, importPKCS8, importSPKI, jwtVerify } from 'jose'
import * as OTPAuth from 'otpauth'

import { AuthenticationError } from '@/errors'
import { Permissions } from '@/permissions'
import { loadKeys, parseGenericError } from '@/utils'

import { SignScopedJWT } from '@/jwt'
import { JWTInvalid } from 'jose/errors'

import type { APIReply } from '@/globals'

const prisma = new PrismaClient()

type UserLoginInput = Prisma.UserWhereUniqueInput & {
	password: string
	totp?: string
}

const { privateKeyPem, publicKeyPem } = loadKeys()

const privateKey = await importPKCS8(privateKeyPem, 'P256')
const publicKey = await importSPKI(publicKeyPem, 'P256')

const tokens: FastifyPluginCallback = (fastify, _, done) => {
	fastify.post<{ Body: UserLoginInput; Reply: APIReply }>(
		'/',
		async (request, reply) => {
			const user = await prisma.user.findUnique({
				where: { name: request.body.name },
			})

			if (user === null)
				throw new AuthenticationError('Invalid username or password')

			const passwordIsCorrect = await argon2.verify(
				user.password,
				request.body.password,
			)

			if (!passwordIsCorrect)
				throw new AuthenticationError('Invalid username or password', {
					id: user.id,
				})

			if (user.totp_url) {
				if (!request.body.totp)
					return reply.status(200).send({ data: { status: 'totp_required' } })
				const totp = OTPAuth.URI.parse(user.totp_url)
				const isTOTPValid = totp.validate({ token: request.body.totp })

				if (isTOTPValid !== 0)
					return reply.status(401).send({ error: 'Invalid TOTP token' })
			}
			// Creating the first access and refresh tokens
			const accessToken = await new SignScopedJWT({
				scope: [
					Permissions.PROFILE_READ,
					Permissions.PROFILE_WRITE,
					Permissions.KEYS_READ,
				],
			})
				.setProtectedHeader({ alg: 'RS256' })
				.setIssuedAt()
				.setSubject(user.id)
				.setExpirationTime('15m')
				.sign(privateKey)

			const refreshToken = await new SignJWT()
				.setProtectedHeader({ alg: 'RS256' })
				.setIssuedAt()
				.setSubject(user.id)
				.setExpirationTime('30d')
				.sign(privateKey)

			// This needs to be stored in the database
			await prisma.refreshToken.create({
				data: {
					value: refreshToken,
					user: { connect: { id: user.id } },
				},
			})

			reply
				.status(201)
				.setCookie('refreshToken', refreshToken, {
					path: '/',
					httpOnly: true,
					sameSite: 'strict',
				})
				.send({ data: { accessToken } })
		},
	)

	fastify.put<{ Reply: APIReply }>('/', async (request, reply) => {
		// Forcing non null since we know the cookie is set because of the authentication hook
		const refreshToken = request.cookies?.refreshToken

		if (!refreshToken) throw new JWTInvalid('Missing refresh token')

		const { payload } = await jwtVerify(refreshToken, publicKey)
		const user = await prisma.user.findUniqueOrThrow({
			where: { id: payload.sub },
		})

		const accessToken = await new SignScopedJWT({
			scope: [
				Permissions.PROFILE_READ,
				Permissions.PROFILE_WRITE,
				Permissions.KEYS_READ,
			],
		})
			.setProtectedHeader({ alg: 'HS256' })
			.setIssuedAt()
			.setSubject(user.id)
			.setExpirationTime('15m')
			.sign(privateKey)
		reply.status(200).send({ data: { accessToken } })
	})

	fastify.setErrorHandler(async (error, request, reply) => {
		const apiError = parseGenericError(error)

		request.log.error(apiError.message)

		return reply
			.code(apiError.statusCode)
			.send({ error: apiError.responseMessage })
	})

	done()
}

export default tokens

import { type Prisma, PrismaClient } from '@prisma/client'
import * as argon2 from 'argon2'
import type { FastifyPluginCallback } from 'fastify'
import { SignJWT, jwtVerify } from 'jose'
import * as OTPAuth from 'otpauth'

import { AuthenticationError } from '@/errors'
import { Permissions } from '@/permissions'
import { parseGenericError } from '@/utils'

import { SignScopedJWT } from '@/jwt'
import { JWTInvalid } from 'jose/errors'

import type { APIReply } from '@/globals'

if (!process.env.JWT_SECRET) {
	console.error('JWT_SECRET is not defined')
	process.exit(1)
}

const prisma = new PrismaClient()

type UserLoginInput = Prisma.UserWhereUniqueInput & {
	password: string
	totp?: string
}

// TODO: switch to a more robust secret (e.g. a private key)
const secret = new TextEncoder().encode(process.env.JWT_SECRET)

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
					return reply.status(401).send({ error: { status: 'totp_invalid' } })
			}
			// Creating the first access and refresh tokens
			const accessToken = await new SignScopedJWT({
				scope: [Permissions.PROFILE_READ, Permissions.PROFILE_WRITE],
			})
				.setProtectedHeader({ alg: 'HS256' })
				.setIssuedAt()
				.setSubject(user.id)
				.setExpirationTime('15m')
				.sign(secret)

			const refreshToken = await new SignJWT()
				.setProtectedHeader({ alg: 'HS256' })
				.setIssuedAt()
				.setSubject(user.id)
				.setExpirationTime('30d')
				.sign(secret)

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

		const { payload } = await jwtVerify(refreshToken, secret)
		const user = await prisma.user.findUniqueOrThrow({
			where: { id: payload.sub },
		})

		const accessToken = await new SignScopedJWT({
			scope: [Permissions.PROFILE_READ, Permissions.PROFILE_WRITE],
		})
			.setProtectedHeader({ alg: 'HS256' })
			.setIssuedAt()
			.setSubject(user.id)
			.setExpirationTime('15m')
			.sign(secret)
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

import type { Prisma } from '@prisma/client'
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library.js'
import * as argon2 from 'argon2'
import type { FastifyPluginCallback } from 'fastify'
import { jwtVerify } from 'jose'
import * as OTPAuth from 'otpauth'

import { AuthenticationError, AuthorizationError } from '@/errors'
import type { APIReply, UserParams } from '@/globals'
import { authenticationHook, authorizationHook } from '@/hooks'
import { Permissions } from '@/permissions'
import { exclude, generateRandomBase32String, parseGenericError } from '@/utils'

import keys from '@api/v1/routes/keys'
import messages from '@api/v1/routes/messages'

if (!process.env.JWT_SECRET) {
	console.error('JWT_SECRET is not defined')
	process.exit(1)
}

const secret = new TextEncoder().encode(process.env.JWT_SECRET)
const users: FastifyPluginCallback = (fastify, _, done) => {
	fastify.register(keys)
	fastify.register(messages)

	fastify.route<{ Reply: APIReply; Params: UserParams }>({
		method: 'GET',
		url: '/:id',
		preParsing: [
			authenticationHook,
			authorizationHook([Permissions.PROFILE_READ]),
		],
		handler: async (request, reply) => {
			if (request.params.id !== request.authenticatedUser?.id)
				throw new AuthorizationError('You can only access your own profile')

			const user = await fastify.prisma.user.findUniqueOrThrow({
				where: { id: request.params.id },
			})

			reply.status(200).send({ data: exclude(user, ['password', 'totp_url']) })
		},
	})

	fastify.post<{ Body: Prisma.UserCreateInput; Reply: APIReply }>(
		'/',
		async (request, reply) => {
			const newUser = await fastify.prisma.user.create({
				data: {
					name: request.body.name,
					password: await argon2.hash(request.body.password),
				},
			})

			reply.status(201).send({ data: { id: newUser.id } })
		},
	)

	fastify.route<{
		Body: Prisma.UserUpdateInput & { enable_totp?: boolean }
		Reply: APIReply
		Params: UserParams
	}>({
		method: 'PATCH',
		url: '/:id',
		preParsing: authenticationHook,
		handler: async (request, reply) => {
			let totp: OTPAuth.TOTP | undefined

			if (request.params.id !== request.authenticatedUser?.id)
				throw new AuthorizationError('You can only access your own profile')

			// If the user wants to enable TOTP, we generate a new URL
			if (request.body.enable_totp) {
				if (!request.body.password)
					throw new AuthenticationError('Need a valid password to enable TOTP')
				totp = new OTPAuth.TOTP({
					issuer: 'POC Flutter',
					algorithm: 'SHA256',
					digits: 6,
					period: 30,
					secret: generateRandomBase32String(32),
				})
			}

			const updatedUser = await fastify.prisma.user.update({
				where: {
					id: request.params.id,
				},
				data: {
					totp_url:
						request.body.enable_totp && totp ? totp.toString() : undefined,
				},
			})

			if (!updatedUser)
				throw new PrismaClientKnownRequestError('User not found', {
					code: 'P2025',
					clientVersion: fastify.prismaVersion,
				})

			if (totp) {
				reply.status(200).send({ data: { totp: totp.toString() } })
				return
			}
			reply.status(204).send()
		},
	})

	fastify.route<{ Reply: APIReply; Params: UserParams }>({
		method: 'DELETE',
		url: '/:id',
		preParsing: authenticationHook,
		handler: async (request, response) => {
			const accessToken = request.headers.authorization?.split(' ')[1]
			const { payload } = await jwtVerify(accessToken || '', secret)

			if (request.params.id !== request.authenticatedUser?.id)
				throw new AuthorizationError('You can only access your own profile')

			await fastify.prisma.user.delete({
				where: {
					id: request.params.id,
				},
			})

			response.status(204).send()
		},
	})

	fastify.setErrorHandler(async (error, request, reply) => {
		const apiError = parseGenericError(error, {
			notFoundMessage:
				'The user you provided does not exist in our database. Please double check your user ID and try again.',
			duplicateMessage:
				'The username you are trying to register with already exists.',
		})

		request.log.error(apiError.message)

		return reply
			.code(apiError.statusCode)
			.send({ error: apiError.responseMessage })
	})
	done()
}

export default users

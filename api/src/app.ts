import cookie from '@fastify/cookie'
import type { FastifyCookieOptions } from '@fastify/cookie'
import { PrismaClient } from '@prisma/client'
import Fastify from 'fastify'

import tokens from '@/routes/v1/tokens'
import users from '@/routes/v1/users'

const fastify = Fastify({ logger: true })

if (process.env.COOKIE_SECRET === undefined) {
	console.error('COOKIE_SECRET is not defined')
	process.exit(1)
}

fastify.register(users, { prefix: '/v1/users' })
fastify.register(tokens, { prefix: '/v1/tokens' })

fastify.register(cookie, {
	secret: process.env.COOKIE_SECRET,
	parseOptions: {},
} as FastifyCookieOptions)

export default fastify

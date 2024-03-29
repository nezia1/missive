import cookie from '@fastify/cookie'
import type { FastifyCookieOptions } from '@fastify/cookie'
import { PrismaClient } from '@prisma/client'
import Fastify from 'fastify'

import tokens from '@/routes/tokens'
import users from '@/routes/users'

const fastify = Fastify({ logger: true })

if (process.env.COOKIE_SECRET === undefined) {
	console.error('COOKIE_SECRET is not defined')
	process.exit(1)
}

fastify.register(users, { prefix: '/users' })
fastify.register(tokens, { prefix: '/tokens' })
fastify.register(cookie, {
	secret: process.env.COOKIE_SECRET,
	parseOptions: {},
} as FastifyCookieOptions)

export default fastify

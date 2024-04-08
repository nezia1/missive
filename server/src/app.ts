import prismaPlugin from '@/plugins/prisma'
import tokens from '@api/v1/routes/tokens'
import users from '@api/v1/routes/users'
import cookie from '@fastify/cookie'
import type { FastifyCookieOptions } from '@fastify/cookie'
import fastifyWs from '@fastify/websocket'
import websocket from '@ws/index'
import Fastify from 'fastify'

const fastify = Fastify({ logger: true })

if (process.env.COOKIE_SECRET === undefined) {
	console.error('COOKIE_SECRET is not defined')
	process.exit(1)
}

const apiPrefix = '/api/v1'

fastify.register(prismaPlugin)
fastify.register(fastifyWs)
fastify.register(users, { prefix: `${apiPrefix}/users` })
fastify.register(tokens, { prefix: `${apiPrefix}/tokens` })
fastify.register(websocket)

fastify.register(cookie, {
	secret: process.env.COOKIE_SECRET,
	parseOptions: {},
} as FastifyCookieOptions)

export default fastify

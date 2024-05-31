import fp from 'fastify-plugin'

import type { FastifyPluginAsync } from 'fastify'

import { Prisma, PrismaClient } from '@prisma/client'

// Use TypeScript module augmentation to declare the type of server.prisma to be PrismaClient

declare module 'fastify' {
	interface FastifyInstance {
		prisma: PrismaClient
		prismaVersion: string
	}
}

interface PrismaPluginOptions {
	prismaClient?: PrismaClient
}
const prismaPlugin: FastifyPluginAsync<PrismaPluginOptions> = async (
	server,
	options,
) => {
	const prisma = options.prismaClient || new PrismaClient()

	await prisma.$connect()

	// Make Prisma Client available through the fastify server instance: server.prisma

	server.decorate('prisma', prisma)
	server.decorate('prismaVersion', Prisma.prismaVersion.client)

	server.addHook('onClose', async (server) => {
		await server.prisma.$disconnect()
	})
}

export default fp(prismaPlugin)

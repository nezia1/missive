import prismaClient from '@/prisma'
import { Prisma, type PrismaClient } from '@prisma/client/extension'
import type { FastifyPluginAsync } from 'fastify'
import fp from 'fastify-plugin'

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
	const prisma = options.prismaClient || prismaClient
	await prisma.$connect()

	// Make Prisma Client available through the fastify server instance: server.prisma

	server.decorate('prisma', prisma)
	server.decorate('prismaVersion', Prisma.prismaVersion.client)

	server.addHook('onClose', async (server) => {
		await server.prisma.$disconnect()
	})
}

export default fp(prismaPlugin)

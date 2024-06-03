import prisma from '@/__mocks__/prisma'
import app from '@/app'
import { sampleUsers } from '@/constants'
import { authenticationHook, authorizationHook } from '@/hooks'
import type * as jwt from '@/jwt'
import { Permissions } from '@/permissions'
import type { KeyLike } from 'jose'
import {
	type Mock,
	afterAll,
	beforeAll,
	beforeEach,
	describe,
	expect,
	it,
	vi,
} from 'vitest'

const alice = sampleUsers[0]
const bob = sampleUsers[1]

let aliceWs: WebSocket
let bobWs: WebSocket

let mockVerifyAndDecodeScopedJWT: Mock<
	[string, KeyLike],
	Promise<jwt.ScopedJWTPayload>
>
beforeAll(async () => {
	vi.mock('@/prisma')
	mockVerifyAndDecodeScopedJWT = vi.fn()
	app.addHook('preParsing', authenticationHook(mockVerifyAndDecodeScopedJWT))
	await app.ready()
})

beforeEach(async () => {
	prisma.user.findUniqueOrThrow.mockResolvedValue(alice)
	mockVerifyAndDecodeScopedJWT.mockResolvedValue({
		sub: alice.id,
		scope: [Permissions.MESSAGES_READ],
	})
	aliceWs = await app.injectWS('/', {
		headers: {
			authorization: 'Bearer valid-token',
		},
	})

	prisma.user.findUniqueOrThrow.mockResolvedValue(bob)
	mockVerifyAndDecodeScopedJWT.mockResolvedValue({
		sub: bob.id,
		scope: [Permissions.MESSAGES_READ],
	})
	bobWs = await app.injectWS('/', {
		headers: {
			authorization: 'Bearer valid-token',
		},
	})
})

afterAll(async () => {
	aliceWs.terminate()
	bobWs.terminate()
})
describe('Connections', () => {
	it('should accept connections', async () => {
		expect(aliceWs).toBeDefined()
	})
	it('should handle disconnections', async () => {
		return new Promise<void>((resolve) => {
			aliceWs.on('close', () => {
				expect(aliceWs.readyState).toBe(aliceWs.CLOSED)
				resolve()
			})
			aliceWs.terminate()
		})
	})
})

describe('Messages', () => {
	it('should send message directly to receiver if they are online', async () => {
		prisma.user.findUnique.mockResolvedValueOnce(bob)
		aliceWs.send(
			JSON.stringify({
				id: '1',
				content: 'hello',
				receiver: 'bob',
			}),
		)

		// Wrapping in promise since it's an async callback and we want to await for it before ending the test
		const receivedMessage = new Promise<string>((resolve) => {
			bobWs.on('message', (message) => {
				resolve(message.toString())
			})
		})

		expect(JSON.parse(await receivedMessage).content).toBe('hello')
	})

	it.skip('should store message in database if they are offline', async () => {
		const bobClosing = new Promise<void>((resolve) => {
			bobWs.on('close', () => {
				resolve()
			})
		})

		bobWs.close()

		await bobClosing

		prisma.user.findUnique.mockResolvedValueOnce(bob)
		const testMessage = {
			id: '1',
			content: 'hello',
			receiver: 'bob',
			receiverId: bob.id,
			senderId: alice.id,
			sentAt: new Date(),
		}
		prisma.pendingMessage.create.mockResolvedValueOnce(testMessage)
		aliceWs.send(JSON.stringify(testMessage))

		const wasPendingMessageCreated = prisma.pendingMessage.create.mock.lastCall
		console.log(wasPendingMessageCreated)
		expect(wasPendingMessageCreated).toBe(true)
	})
})

import { sampleUsers } from '@/constants'
import { generateRandomBase32String } from '@/utils'
import { PrismaClient } from '@prisma/client'
import * as argon2 from 'argon2'
import * as OTPAuth from 'otpauth'

const prisma = new PrismaClient()

async function main() {
	const totp = new OTPAuth.TOTP({
		issuer: 'POC Flutter',
		algorithm: 'SHA256',
		digits: 6,
		period: 30,
		secret: generateRandomBase32String(32),
	})

	for (const user of sampleUsers) {
		const { name, password } = user

		const hashedPassword = await argon2.hash(password)
		await prisma.user.create({
			data: {
				name,
				password: hashedPassword,
				totp_url: user.totp ? totp.toString() : null,
			},
		})
	}
}

await main()
	.then(async () => {
		await prisma.$disconnect()
	})

	.catch(async (e) => {
		console.error(e)

		await prisma.$disconnect()

		process.exit(1)
	})

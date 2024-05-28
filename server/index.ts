import app from '@/app'

try {
	await app.listen({ port: 8080, host: '0.0.0.0' })
} catch (err) {
	app.log.error(err)
	app.log.error(process.env.DATABASE_URL)
	process.exit(1)
}

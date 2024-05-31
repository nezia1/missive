/**
 * @file This file contains the entry point of the application. It is used to start the server.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

import app from '@/app'

try {
	await app.listen({ port: 8080, host: '0.0.0.0' })
} catch (err) {
	app.log.error(err)
	process.exit(1)
}

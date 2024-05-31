import path from 'node:path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
	test: {
		env: {
			COOKIE_SECRET: 'test',
			POSTGRES_URL: 'postgres://',
		},
	},
	resolve: {
		alias: {
			'@': path.resolve(__dirname, 'src'),
			'@api': path.resolve(__dirname, 'src/api'),
			'@ws': path.resolve(__dirname, 'src/websocket'),
		},
	},
})

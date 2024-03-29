import { StringAsNumber } from 'fastify/types/utils'

// TODO add more status for both interfaces
export interface APIReply {
	'2xx': {
		data: {
			status?: 'totp_required'
			[key: string]: unknown
		}
	}
	204: { [key: string]: never }
	'4xx': {
		status?: 'totp_invalid'
		[key: string]: unknown
	}
}

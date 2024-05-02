// TODO add more status for both interfaces
export interface APIReply {
	'2xx': {
		data: {
			status?: 'totp_required'
			[key: string]: unknown | Array<{ [key: string]: unknown }>
		}
	}
	204: { [key: string]: never }
	'4xx': {
		error: string
	}
}

export interface UserParams {
	id: string
}

export interface MessageParams {
	name: string
}

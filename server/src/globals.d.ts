/**
 * @file This file contains all the types used globally inside the application. More specific types are defined in the relevant files.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

/**
 * This is used by Fastify to strongly type responses for different status codes, since Missive has a different response structure for successes and errors.
 */
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

/**
 * The parameters used to interact with a user.
 */
export interface UserParams {
	id: string
}

/**
 * The parameters used to interact with a message.
 */
export interface MessageParams {
	name: string
}

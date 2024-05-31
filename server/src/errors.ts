/**
 * @file This file contains all the generic errors that can be thrown in the application.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

/**
 * An error that is thrown when authentication fails (wrong username/password invalid TOTP token...).
 */
export class AuthenticationError extends Error {
	id?: string
	constructor(message: string, { id }: { id?: string } = {}) {
		super(message)
		this.name = 'AuthenticationError'
		this.id = id
	}
}

/**
 * An error that is thrown when authorization fails (user does not have permission).
 */
export class AuthorizationError extends Error {
	constructor(message: string) {
		super(message)
		this
	}
}

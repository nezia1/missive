export class AuthenticationError extends Error {
	id?: string
	constructor(message: string, { id }: { id?: string } = {}) {
		super(message)
		this.name = 'AuthenticationError'
		this.id = id
	}
}

export class AuthorizationError extends Error {
	constructor(message: string) {
		super(message)
		this
	}
}

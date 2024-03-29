import {
	PrismaClientInitializationError,
	PrismaClientKnownRequestError,
} from '@prisma/client/runtime/library.js'
import {
	JWSSignatureVerificationFailed,
	JWTExpired,
	JWTInvalid,
} from 'jose/errors'

import { AuthenticationError, AuthorizationError } from './errors'

interface ParseErrorOptions {
	notFoundMessage: string
	duplicateMessage: string
}

interface APIError {
	statusCode: number
	responseMessage: string
	message: string
}
/**
 * Transforms a generic Typescript error into an APIError.
 * @param {Error} error - The error to parse.
 * @param {ParseErrorOptions | undefined} options - allows to configure the different error messages the API will return.
 * @returns {APIError}
 * */
export function parseGenericError(
	error: Error,
	options?: ParseErrorOptions,
): APIError {
	const apiError: APIError = {} as APIError

	// Database errors
	if (error instanceof PrismaClientKnownRequestError) {
		switch (error.code) {
			case 'P2025':
				apiError.statusCode = 404
				apiError.responseMessage =
					options?.notFoundMessage ||
					'The resource you are trying to reach has not been found.'
				break
			case 'P2002':
				apiError.statusCode = 409
				apiError.responseMessage =
					options?.duplicateMessage ||
					'The resource you are trying to create already exists.'
				break
		}
	} else if (error instanceof PrismaClientInitializationError) {
		apiError.statusCode = 500
		apiError.responseMessage =
			'Our servers encountered an unexpected error. We apologize for the inconvenience.'

		// JWT Errors
	} else if (error instanceof JWTInvalid) {
		apiError.statusCode = 401
		apiError.responseMessage = 'Invalid token'
	} else if (error instanceof JWTExpired) {
		apiError.statusCode = 401
		apiError.responseMessage = 'Expired token'
	} else if (error instanceof JWSSignatureVerificationFailed) {
		apiError.statusCode = 401
		apiError.responseMessage = 'The token has been tampered with'

		// Authentication errors (that are not JWT related)
	} else if (error instanceof AuthenticationError) {
		apiError.statusCode = 401
		apiError.responseMessage = error.message
		apiError.message = `Authentication failed for user ${error.id}: ${error.message}`
	} else if (error instanceof AuthorizationError) {
		apiError.statusCode = 403
		apiError.responseMessage = error.message
	}

	// Generic errors
	else if (error instanceof SyntaxError) {
		apiError.statusCode = 400
		apiError.responseMessage = 'Invalid request body'
	} else {
		apiError.statusCode = 500
		apiError.responseMessage =
			'Our servers encountered an unexpected error. We apologize for the inconvenience.'
	}

	// This ternary allows to override the default error message if needed
	apiError.message = apiError.message ? apiError.message : error.message
	return apiError
}

export function generateRandomBase32String(length: number): string {
	// Check if the Web Crypto API is available
	if (!crypto || !crypto.getRandomValues) {
		throw new Error('Web Crypto API not available')
	}

	// Define the Base32 characters
	const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

	// Calculate the number of bytes needed
	const bytesNeeded = Math.ceil((5 * length) / 8)

	// Generate random values
	const randomValues = new Uint8Array(bytesNeeded)
	crypto.getRandomValues(randomValues)

	// Build the Base32 string
	let base32String = ''
	let bits = 0
	let bitsCount = 0

	for (let i = 0; i < randomValues.length; i++) {
		bits = (bits << 8) | randomValues[i]
		bitsCount += 8

		while (bitsCount >= 5) {
			base32String += base32Chars[(bits >>> (bitsCount - 5)) & 0x1f]
			bitsCount -= 5
		}
	}

	// Add padding if needed
	if (bitsCount > 0) {
		base32String += base32Chars[(bits << (5 - bitsCount)) & 0x1f]
	}

	// Trim to the desired length
	return base32String.slice(0, length)
}

/**
 * Excludes fields from a model.
 * @param {T} model - The model to exclude fields from
 **/
export function exclude<T>(model: T, excludedFields: (keyof T)[]): Partial<T> {
	const newModel = { ...model }

	for (const field of excludedFields) {
		delete newModel[field]
	}

	return newModel
}

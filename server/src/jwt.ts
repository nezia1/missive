/**
 * @file This file contains all the JWT related functions.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

import { type JWTPayload, type KeyLike, SignJWT, jwtVerify } from 'jose'
import type { Permissions } from './permissions'

/**
 * This interface is used to extend the JWTPayload interface, and add the scope property.
 */
interface ScopedJWTPayload extends JWTPayload {
	scope?: Permissions[]
}

/**
 * This class is used to extend the SignJWT class, and add the scope property (so we can still use the SignJWT class with strong typing)
 */
export class SignScopedJWT extends SignJWT {
	protected _payload: ScopedJWTPayload

	constructor(payload: ScopedJWTPayload) {
		super(payload)
		this._payload = payload
	}
}

/**
 * Verify and decode a scoped JWT.
 * @param {string} token - The token to verify and decode
 * @param {Uint8Array} secret - The secret to use to verify the token
 * @returns {Promise<ScopedJWTPayload>} - The decoded payload with the scope/permissions
 * @example
 * import { verifyAndDecodeJWT } from './jwt'
 * const payload = await verifyAndDecodeJWT(token, secret)
 */
export async function verifyAndDecodeScopedJWT(
	token: string,
	secret: KeyLike,
): Promise<ScopedJWTPayload> {
	const { payload } = await jwtVerify(token, secret)
	return payload as ScopedJWTPayload
}

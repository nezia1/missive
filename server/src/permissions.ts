/**
 * @file The permissions that a user can have.
 * @author Anthony Rodriguez <anthony@nezia.dev>
 */

export enum Permissions {
	PROFILE_READ = 'profile:read',
	PROFILE_WRITE = 'profile:write',
	KEYS_READ = 'keys:read',
	KEYS_WRITE = 'keys:write',
	MESSAGES_READ = 'messages:read',
}

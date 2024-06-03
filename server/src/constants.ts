/**
 * List of sample users. Used when seeding the database for testing purposes.
 */
export const sampleUsers = [
	{
		id: '1',
		name: 'alice',
		password: 'Super',
		totp_url: null,
		createdAt: new Date(),
		updatedAt: new Date(),
		registrationId: 1,
		identityKey: '1',
		notificationID: '1',
	},
	{
		id: '2',
		name: 'bob',
		password: 'Super',
		totp_url: null,
		createdAt: new Date(),
		updatedAt: new Date(),
		registrationId: 2,
		identityKey: '2',
		notificationID: '2',
	},
]

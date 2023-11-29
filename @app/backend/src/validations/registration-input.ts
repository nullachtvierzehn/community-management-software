export const registrationInput = {
  type: 'object',
  additionalProperties: false,
  properties: {
    username: { type: 'string' },
    email: { type: 'string' },
    name: { type: 'string' },
    avatarUrl: { type: 'string' },
    password: { type: 'string' },
  },
  required: ['username', 'email', 'password'],
} as const

export default registrationInput

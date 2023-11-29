export const loginInput = {
  type: 'object',
  additionalProperties: false,
  properties: {
    username: { type: 'string' },
    password: { type: 'string' },
  },
  required: ['username', 'password'],
} as const

export default loginInput

import type { RoomRole } from '~/graphql'

export default function orderOfRole(role: RoomRole): number {
  switch (role) {
    case 'BANNED':
      return -1
    case 'PUBLIC':
      return 0
    case 'PROSPECT':
      return 1
    case 'MEMBER':
      return 2
    case 'MODERATOR':
      return 3
    case 'ADMIN':
      return 4
    default:
      throw new Error(`unsupported value: ${role}`)
  }
}

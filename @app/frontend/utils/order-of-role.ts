import type { RoomRole } from '~/graphql'

export default function orderOfRole(role: RoomRole): number {
  switch (role) {
    case 'BANNED':
      return -1
    case 'PROSPECT':
      return 0
    case 'PUBLIC':
    case 'MEMBER':
      return 1
    case 'MODERATOR':
      return 2
    case 'ADMIN':
      return 3
    default:
      throw new Error(`unsupported value: ${role}`)
  }
}

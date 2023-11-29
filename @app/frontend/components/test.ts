import { useCreateRoomMessageMutation, type RoomMessageInput } from '~/graphql'

const { data } = useCreateRoomMessageMutation()
export { type RoomMessageInput }

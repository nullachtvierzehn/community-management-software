import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import {
  type GetRoomQuery,
  type RoomPatch,
  type RoomRole,
  useCreateRoomSubscriptionMutation,
  useDeleteRoomSubscriptionByRoomAndUserMutation,
  useGetRoomQuery,
  useUpdateRoomMutation,
} from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

export type UseRoomOptions = { id: MaybeRef<string> }
export type Room = GetRoomQuery['room'] | undefined
export type RoomRef = ActsAsPromiseLike<ComputedRef<Room>>

export const roomInjectionKey = Symbol('currentRoom') as InjectionKey<RoomRef>

export function useRoom(options?: UseRoomOptions): RoomRef {
  const injectedRoomRef = inject(roomInjectionKey, undefined)

  if (!options?.id) {
    if (injectedRoomRef) return injectedRoomRef
    else throw new Error('cannot inject room')
  }

  // The injected room matches the given ID, so return it.
  else if (injectedRoomRef?.value?.id === toValue(options.id)) {
    return injectedRoomRef
  }

  // Get the room from GraphQL
  const response = useGetRoomQuery({
    variables: computed(() => ({ id: toValue(options.id) })),
    requestPolicy: 'cache-and-network',
  })

  const room = computed(() => response.data.value?.room) as RoomRef

  // Prepare update
  /*
  async function update(patch: RoomPatch) {
    const currentRoom = toValue(room)
    if (!currentRoom) throw new Error('no current room')
    await updateMutation({ oldId: currentRoom.id, patch })
  }
  */

  // Add `then` for a promise-like interface
  room.then = function (onResolve, onReject) {
    return response
      .then(
        ({ data }) => computed(() => data.value?.room),
        (reason) => {
          throw reason
        }
      )
      .then(onResolve, onReject)
  }

  provide(roomInjectionKey, room)
  return room
}

export function useRoomWithTools(options?: UseRoomOptions): ActsAsPromiseLike<{
  room: ComputedRef<Room>
  mySubscription: ComputedRef<NonNullable<Room>['mySubscription'] | undefined>
  update: (patch: RoomPatch) => Promise<void>
  subscribe: (role?: RoomRole) => Promise<void>
  unsubscribe: () => Promise<void>
}> {
  const room = useRoom(options)
  const user = useCurrentUser()
  const { executeMutation: updateMutation } = useUpdateRoomMutation()
  const { executeMutation: subscribeMutation } =
    useCreateRoomSubscriptionMutation()
  const { executeMutation: unsubscribeMutation } =
    useDeleteRoomSubscriptionByRoomAndUserMutation()

  const mySubscription = computed(() => room.value?.mySubscription)

  async function update(patch: RoomPatch) {
    const thisRoom = toValue(room)
    if (!thisRoom) throw Error('room is unavailable')
    const { error } = await updateMutation({ oldId: thisRoom.id, patch })
    if (error) throw error
  }

  async function subscribe(role?: RoomRole) {
    const thisRoom = toValue(room)
    const thisUser = toValue(user)
    if (!thisRoom) throw Error('room is unavailable')
    if (!thisUser) throw Error('user is signed out')
    const { error } = await subscribeMutation({
      subscription: { roomId: thisRoom.id, subscriberId: thisUser.id, role },
    })
    if (error) throw error
  }

  async function unsubscribe() {
    const thisRoom = toValue(room)
    const thisUser = toValue(user)
    if (!thisRoom) throw Error('room is unavailable')
    if (!thisUser) throw Error('user is signed out')
    const { error } = await unsubscribeMutation({
      roomId: thisRoom.id,
      userId: thisUser.id,
    })
    if (error) throw error
  }

  return {
    room,
    update,
    mySubscription,
    subscribe,
    unsubscribe,
    then(onResolve, onReject) {
      return room
        .then(
          (resolvedRef) => ({
            room: resolvedRef,
            update,
            mySubscription: computed(() => resolvedRef.value?.mySubscription),
            subscribe,
            unsubscribe,
          }),
          (reason) => {
            throw reason
          }
        )
        .then(onResolve, onReject)
    },
  }
}

import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import { type GetRoomQuery, type RoomPatch, useGetRoomQuery } from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

export type Room = GetRoomQuery['room'] | undefined

export type RoomRef = ActsAsPromiseLike<ComputedRef<Room>>

export const roomInjectionKey = Symbol('currentRoom') as InjectionKey<RoomRef>

export function useRoom(options?: { id: MaybeRef<string> }): RoomRef {
  const injectedRoomRef = inject(roomInjectionKey)

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
    const promise = response.then((value) => {
      return computed(() => value.data.value?.room)
    })
    return promise.then(onResolve, onReject)
  }

  provide(roomInjectionKey, room)
  return room
}

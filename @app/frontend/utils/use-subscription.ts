import { computed, type ComputedRef, inject, type InjectionKey } from 'vue'

import {
  type RoomSubscriptionPatch,
  type ShortRoomSubscriptionFragment,
  useGetRoomSubscriptionOfUserInRoomQuery,
  useUpdateRoomSubscriptionMutation,
} from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

import type { UseRoomOptions } from './use-room'

export type Subscription = ShortRoomSubscriptionFragment | null | undefined
export type SubscriptonRef = ActsAsPromiseLike<ComputedRef<Subscription>>

export const subscriptionInjectionKey = Symbol(
  'currentSubscription'
) as InjectionKey<SubscriptonRef>

export function useSubscription(options?: UseRoomOptions): SubscriptonRef {
  const room = useRoom(options)
  const user = useCurrentUser()

  const injectedSubscriptionRef = inject(
    subscriptionInjectionKey,
    () => {
      const response = useGetRoomSubscriptionOfUserInRoomQuery({
        variables: computed(() => ({
          roomId: room.value?.id as string,
          userId: user.value?.id as string,
        })),
        pause: computed(() => !room.value || !user.value),
        requestPolicy: 'cache-and-network',
      })

      const currentSubscription = computed(
        () => response.data.value?.roomSubscriptionBySubscriberIdAndRoomId
      ) as SubscriptonRef

      currentSubscription.then = function (onResolve, onReject) {
        function throwReason(reason: any): never {
          throw reason
        }

        return Promise.all([room, user])
          .then(([_resolvedRoom, _resolvedUser]) => response, throwReason)
          .then(
            ({ data }) =>
              computed(
                () => data.value?.roomSubscriptionBySubscriberIdAndRoomId
              ),
            throwReason
          )
          .then(onResolve, onReject)
      }

      return currentSubscription
    },
    true
  )

  return injectedSubscriptionRef
}

export function useSubscriptionWithTools(
  options?: UseRoomOptions
): ActsAsPromiseLike<{
  subscription: ComputedRef<Subscription>
  update: (patch: RoomSubscriptionPatch) => Promise<void>
}> {
  const subscription = useSubscription(options)
  const { executeMutation: updateMutation } =
    useUpdateRoomSubscriptionMutation()

  async function update(patch: RoomSubscriptionPatch) {
    const thisSubscription = toValue(subscription)
    if (!thisSubscription) throw Error('subscription is unavailable')
    const { error } = await updateMutation({
      oldId: thisSubscription.id,
      patch,
    })
    if (error) throw error
  }

  return {
    subscription,
    update,
    then(onResolve, onReject) {
      return subscription
        .then(
          (resolvedRef) => ({ subscription: resolvedRef, update }),
          (reason) => {
            throw reason
          }
        )
        .then(onResolve, onReject)
    },
  }
}

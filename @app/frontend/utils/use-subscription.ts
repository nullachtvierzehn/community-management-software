import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import {
  type ShortRoomSubscriptionFragment,
  useGetRoomSubscriptionOfUserInRoomQuery,
} from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

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
      })

      const currentSubscription = computed(
        () => response.data.value?.roomSubscriptionBySubscriberIdAndRoomId
      ) as SubscriptonRef

      currentSubscription.then = function (onResolve, onReject) {
        return Promise.all([room, user])
          .then(
            (_resolvedResponseDependencies) => response,
            (reason) => {
              throw reason
            }
          )
          .then(
            ({ data }) =>
              computed(
                () => data.value?.roomSubscriptionBySubscriberIdAndRoomId
              ),
            (reason) => {
              throw reason
            }
          )
          .then(onResolve, onReject)
      }

      return currentSubscription
    },
    true
  )

  return injectedSubscriptionRef
}

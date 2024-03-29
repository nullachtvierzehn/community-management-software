import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import { type CurrentUserQuery, useCurrentUserQuery } from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

export type CurrentUser = CurrentUserQuery['currentUser'] | undefined

export const currentUserInjectionKey = Symbol('currentUser') as InjectionKey<
  ActsAsPromiseLike<ComputedRef<CurrentUser>>
>

export function useCurrentUser(): ActsAsPromiseLike<ComputedRef<CurrentUser>> {
  return inject(
    currentUserInjectionKey,
    () => {
      const response = useCurrentUserQuery({
        requestPolicy: 'cache-and-network',
      })

      // create computed rect
      const currentUser = computed(
        () => response.data.value?.currentUser
      ) as ActsAsPromiseLike<ComputedRef<CurrentUser>>

      // add promise interface
      const promise = response.then(
        () => {
          return computed(() => response.data.value?.currentUser)
        },
        (reason) => {
          throw reason
        }
      )

      currentUser.then = function (onResolve, onReject) {
        return promise.then(onResolve, onReject)
      }

      provide(currentUserInjectionKey, currentUser)
      return currentUser
    },
    true
  )
}

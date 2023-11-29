import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import {
  type GetCurrentUserQuery,
  useGetCurrentUserQuery,
} from '~/graphql/index.js'

export type CurretUser = GetCurrentUserQuery['currentUser'] | undefined

export const currentUserInjectionKey = Symbol('currentUser') as InjectionKey<
  ComputedRef<CurretUser>
>

export function useCurrentUser() {
  return inject(
    currentUserInjectionKey,
    () => {
      const { data } = useGetCurrentUserQuery({
        requestPolicy: 'cache-and-network',
      })
      const ref = computed(() => data.value?.currentUser)
      provide(currentUserInjectionKey, ref)
      return ref
    },
    true
  )
}

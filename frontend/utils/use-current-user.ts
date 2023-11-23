import { type GetCurrentUserQuery, useGetCurrentUserQuery } from "~/graphql";
import {
  type ComputedRef,
  type InjectionKey,
  computed,
  inject,
  provide,
} from "vue";

export type CurretUser = GetCurrentUserQuery["currentUser"] | undefined;

export const currentUserInjectionKey = Symbol("currentUser") as InjectionKey<
  ComputedRef<CurretUser>
>;

export function useCurrentUser() {
  return inject(
    currentUserInjectionKey,
    () => {
      const { data } = useGetCurrentUserQuery({
        requestPolicy: "cache-and-network",
      });
      const ref = computed(() => data.value?.currentUser);
      provide(currentUserInjectionKey, ref);
      return ref;
    },
    true
  );
}
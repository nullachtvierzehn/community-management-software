import { type InjectionKey, type ComputedRef } from "vue";
import { type GetRoomQuery } from "~/graphql";

export const roomInjectionKey = Symbol() as InjectionKey<
  ComputedRef<GetRoomQuery["room"] | undefined>
>;

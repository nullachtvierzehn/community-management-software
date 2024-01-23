import {
  type OperationResult,
  type UseQueryArgs,
  type UseQueryResponse,
} from '@urql/vue'
import { omit } from 'lodash-es'
import {
  computed,
  type ComputedRef,
  inject,
  type InjectionKey,
  provide,
} from 'vue'

import {
  type CreateRoomItemMutation,
  type CreateRoomItemMutationVariables,
  type FetchRoomItemsQuery,
  type FetchRoomItemsQueryVariables,
  type GetRoomQuery,
  type InputMaybe,
  type RoomItemCondition,
  type RoomItemFilter,
  type RoomItemInput,
  type RoomPatch,
  type RoomRole,
  type RoomSubscriptionPatch,
  useCreateRoomItemMutation,
  useCreateRoomSubscriptionMutation,
  useDeleteRoomSubscriptionByRoomAndUserMutation,
  useFetchRoomItemsQuery,
  useGetRoomQuery,
  useUpdateRoomMutation,
  useUpdateRoomSubscriptionMutation,
} from '~/graphql'
import { type ActsAsPromiseLike } from '~/utils/types'

export type Room = GetRoomQuery['room'] | undefined
export type RoomRef = ActsAsPromiseLike<ComputedRef<Room>>
export interface UseRoomOptions {
  id: MaybeRef<string>
}

interface FetchRoomItemsQueryVariablesWithoutRoomId
  extends Omit<FetchRoomItemsQueryVariables, 'condition' | 'filter'> {
  condition?: InputMaybe<Omit<RoomItemCondition, 'roomId'>>
  filter?: InputMaybe<Omit<RoomItemFilter, 'roomId'>>
}

type FetchRoomItemsOptions = Omit<
  UseQueryArgs<never, FetchRoomItemsQueryVariablesWithoutRoomId>,
  'query'
>

export interface FetchItemsReturn
  extends Omit<
    UseQueryResponse<
      FetchRoomItemsQuery,
      FetchRoomItemsQueryVariablesWithoutRoomId
    >,
    'executeQuery' | 'then'
  > {
  items: ComputedRef<RoomItemFromFetchQuery[]>
  refetch: UseQueryResponse<
    FetchRoomItemsQuery,
    FetchRoomItemsQueryVariablesWithoutRoomId
  >['executeQuery']
}

export type AddRoomItemReturn =
  | NonNullable<
      NonNullable<
        OperationResult<
          CreateRoomItemMutation,
          CreateRoomItemMutationVariables
        >['data']
      >['createRoomItem']
    >['roomItem']
  | undefined

export interface UseRoomWithRoolsReturn {
  room: ComputedRef<Room>
  mySubscription: ComputedRef<NonNullable<Room>['mySubscription'] | undefined>
  update: (patch: RoomPatch) => Promise<void>
  updateMySubscription: (patch: RoomSubscriptionPatch) => Promise<void>
  subscribe: (role?: RoomRole) => Promise<void>
  unsubscribe: () => Promise<void>
  hasRole: (role: RoomRole, options: { orHigher?: boolean }) => boolean
  fetching: Readonly<Ref<boolean>>
  fetchItems(options: FetchRoomItemsOptions): FetchItemsReturn
  addItem(item: RoomItemInput): Promise<AddRoomItemReturn>
}

export type RoomItemFromFetchQuery = NonNullable<
  FetchRoomItemsQuery['roomItems']
>['nodes'][0]

export const roomWithToolsInjectionKey = Symbol(
  'currentRoomWithTools'
) as InjectionKey<ActsAsPromiseLike<UseRoomWithRoolsReturn>>

export function useRoom(
  options?: UseRoomOptions
): ActsAsPromiseLike<UseRoomWithRoolsReturn> {
  const injected = inject(roomWithToolsInjectionKey, undefined)

  // Propagate the injected value if `id` is missing.
  if (!options?.id) {
    if (injected) return injected
    else throw new Error('cannot inject room')
  }

  // Propagate the injected value if it matches the `options.id`
  else if (injected?.room.value?.id === toValue(options.id)) {
    return injected
  }

  // Get the room from GraphQL
  const response = useGetRoomQuery({
    variables: computed(() => ({ id: toValue(options.id) })),
    requestPolicy: 'cache-and-network',
  })

  const room = computed(() => response.data.value?.room)
  const user = useCurrentUser()
  const mySubscription = computed(() => room.value?.mySubscription)

  // Update rooms.
  const { executeMutation: updateMutation } = useUpdateRoomMutation()

  async function update(patch: RoomPatch) {
    const thisRoom = toValue(room)
    if (!thisRoom) throw Error('room is unavailable')
    const { error } = await updateMutation({ oldId: thisRoom.id, patch })
    if (error) throw error
  }

  // Update my subscription.
  const { executeMutation: updateSubscriptionMutation } =
    useUpdateRoomSubscriptionMutation()

  async function updateMySubscription(patch: RoomSubscriptionPatch) {
    const thisSubscription = toValue(mySubscription)
    if (!thisSubscription) throw Error('subscription is unavailable')
    const { error } = await updateSubscriptionMutation({
      oldId: thisSubscription.id,
      patch,
    })
    if (error) throw error
  }

  // Subscribe to room
  const { executeMutation: subscribeMutation } =
    useCreateRoomSubscriptionMutation()

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

  // Unsubscribe from room
  const { executeMutation: unsubscribeMutation } =
    useDeleteRoomSubscriptionByRoomAndUserMutation()

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

  // Utility to check one's role in a room.
  function hasRole(role: RoomRole, { orHigher = true }) {
    if (!mySubscription.value) return false
    if (orHigher)
      return orderOfRole(mySubscription.value.role) >= orderOfRole(role)
    else return mySubscription.value.role === role
  }

  const addedItem = createEventHook<AddRoomItemReturn>()

  // Utility to fetch items
  function fetchItems(
    options: FetchRoomItemsOptions
  ): ActsAsPromiseLike<FetchItemsReturn> {
    const response = useFetchRoomItemsQuery({
      ...options,
      pause: logicNot(room),
      variables: computed(() => {
        const r = toValue(room)
        const v = toValue(options.variables)
        if (!r) throw new Error('undefined room in fetchItems(...)')
        if (!v) return { condition: { roomId: r.id } }

        const { condition, filter, ...other } = v
        return {
          condition: { ...condition, roomId: r.id } satisfies RoomItemCondition,
          filter: {
            ...filter,
            roomId: { equalTo: r.id },
          } satisfies RoomItemFilter,
          ...other,
        }
      }),
    })

    addedItem.on(
      async () =>
        await response.executeQuery({ requestPolicy: 'cache-and-network' })
    )

    const items = computed(() => response.data.value?.roomItems?.nodes ?? [])
    const out: ActsAsPromiseLike<FetchItemsReturn> = {
      ...omit(response, ['executeQuery', 'then']),
      items,
      refetch: response.executeQuery.bind(response),
      then(onResolve, onReject) {
        return responseLoaded.then(onResolve, onReject)
      },
    }

    const responseLoaded = response.then(
      () => {
        const { then, ...outWithoutThen } = out
        return outWithoutThen
      },
      (reason) => {
        throw reason
      }
    )

    return out
  }

  // Utility to add items
  const { executeMutation: addMutation } = useCreateRoomItemMutation()

  async function addItem(item: RoomItemInput): Promise<AddRoomItemReturn> {
    const { data, error } = await addMutation({ item })
    if (error) throw error
    await addedItem.trigger(data?.createRoomItem?.roomItem)
    return data?.createRoomItem?.roomItem
  }

  const out: ActsAsPromiseLike<UseRoomWithRoolsReturn> = {
    room,
    update,
    updateMySubscription,
    mySubscription,
    subscribe,
    unsubscribe,
    hasRole,
    fetching: response.fetching,
    fetchItems,
    addItem,
    then(onResolve, onReject) {
      return promise.then(onResolve, onReject)
    },
  }

  // Each call to response.then(...) will deliver a new Promise.
  // See https://github.com/urql-graphql/urql/blob/bc2adbdb7468c5b67488dd49fbaa07204322b445/packages/vue-urql/src/useQuery.ts#L387
  // for implementation.
  // We call this to generate exactly one promise, that we will use to cache the resolved value.
  const promise = response.then(
    () => {
      // We have to remove `then`,
      // otherwise we would return something `PromiseLike` and get stuck in an infinite loop of resolutions.
      const { then, ...withoutPromiseInterface } = out
      return withoutPromiseInterface
    },
    (reason) => {
      throw reason
    }
  )

  provide(roomWithToolsInjectionKey, out)
  return out
}

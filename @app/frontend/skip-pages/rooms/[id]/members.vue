<template>
  <section v-if="!room">
    <h1>Fehler: Raum konnte nicht vollständig geladen werden.</h1>
  </section>
  <!-- -->
  <div v-if="room && room.hasSubscriptions && !subscription">
    <div class="bg-gray-200 -mx-4 -mt-4 mb-4">
      <div class="container mx-auto p-4 flex justify-between items-center">
        <div>
          Sie müssen Mitglied im Raum sein, um Mitglieder sehen zu können.
        </div>
        <button class="btn btn_primary" @click="subscribe()">Eintreten</button>
      </div>
    </div>
  </div>
  <section
    v-if="room"
    class="container mx-auto"
    @keyup.esc="showUserModal = false"
  >
    <h1 class="sr-only">Mitglieder</h1>

    <div v-if="subscription?.role === 'ADMIN'" class="flex justify-end">
      <button class="btn btn_primary" @click="showUserModal = true">
        Mitglied hinzufügen
      </button>
    </div>

    <Teleport v-if="showUserModal" to="body">
      <SearchModal
        v-model:show="showUserModal"
        :entities="['USER']"
        :skip-ids="memberIds"
        :focus-on-show="true"
        @click-match="addUserById($event.id)"
      ></SearchModal>
    </Teleport>

    <!-- Show option to become admin of orphaned rooms. -->
    <div v-if="!room.hasSubscriptions">
      <p>Der Raum hat keine Mitglieder.</p>
      <button @click="becomeAdmin()">Ich möchte sein Admin werden.</button>
    </div>

    <!-- Show memberships -->
    <div
      v-if="room.nSubscriptions > '0'"
      class="grid grid-cols-[2fr_1fr_1fr] gap-1 my-4"
    >
      <div class="grid grid-cols-subgrid col-span-3 rounded-md">
        <div class="bg-gray-300 p-4">Login-Name</div>
        <div class="bg-gray-300 p-4">Mitglied seit</div>
        <div class="bg-gray-300 p-4">Status</div>
      </div>
      <room-subscription
        v-for="s in subscriptions"
        :key="s.subscriberId"
        class="grid grid-cols-subgrid col-span-3"
        :value="s"
      >
      </room-subscription>
    </div>
  </section>
</template>

<script lang="ts" setup>
import {
  type RoomRole,
  useCreateRoomSubscriptionMutation,
  useFetchRoomSubscriptionsQuery,
} from '~/graphql'

definePageMeta({
  name: 'room/members',
})

const route = useRoute()
const showUserModal = ref(false)
const {
  room,
  subscribe: subscribeRoom,
  mySubscription: subscription,
} = await useRoom()

const { executeMutation: createSubscription } =
  useCreateRoomSubscriptionMutation()

// fetch subscriptions
const { data: dataOfSubscriptions, executeQuery: refetchSubscriptions } =
  await useFetchRoomSubscriptionsQuery({
    variables: computed(() => ({
      condition: { roomId: route.params.id as string },
      orderBy: ['SUBSCRIBERS_USERNAME_ASC'],
    })),
    requestPolicy: 'cache-and-network',
  })

const subscriptions = computed(
  () => dataOfSubscriptions.value?.roomSubscriptions?.nodes ?? []
)

const memberIds = computed(
  () =>
    dataOfSubscriptions.value?.roomSubscriptions?.nodes.map(
      (n) => n.subscriberId
    ) ?? []
)

async function subscribe(role?: RoomRole) {
  await subscribeRoom(role)
  refetchSubscriptions({ requestPolicy: 'cache-and-network' })
}

async function becomeAdmin() {
  await subscribe('ADMIN')
}

async function addUserById(id: string) {
  const r = toValue(room)
  if (!r) throw new Error('room is not available')
  const { error } = await createSubscription({
    subscription: { roomId: r.id, subscriberId: id, role: 'MEMBER' },
  })
  if (error) throw error
  refetchSubscriptions({ requestPolicy: 'cache-and-network' })
}
</script>

<style lang="postcss" scoped>
:deep(.subscription__username),
:deep(.subscription__role),
:deep(.subscription__date) {
  @apply p-4;
}

:deep(select.subscription__role) {
  @apply border border-gray-700;
}

:deep(.subscription:nth-child(odd)) {
  @apply bg-gray-100;

  & .subscription__role {
    @apply bg-gray-100;
  }
}

:deep(.subscription:nth-child(even)) {
  @apply bg-white;

  & .subscription__role {
    @apply bg-white;
  }
}
</style>

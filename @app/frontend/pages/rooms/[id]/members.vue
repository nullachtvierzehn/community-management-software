<template>
  <section v-if="!currentRoom">
    <h1>Fehler: Raum konnte nicht vollständig geladen werden.</h1>
  </section>
  <section v-else @keyup.esc="showUserModal = false">
    <h1>Mitglieder</h1>
    <button @click="showUserModal = true">+</button>

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
    <div v-if="currentRoom.nSubscriptions === '0' && currentUser">
      <p>Der Raum hat keine Mitglieder.</p>
      <button @click="becomeAdmin()">Ich möchte sein Admin werden.</button>
    </div>

    <!-- Show memberships -->
    <div
      v-for="subscription in subscriptions"
      :key="subscription.subscriberId"
      class="subscription"
    >
      <room-subscription :value="subscription" class="subscription__username">
      </room-subscription>
    </div>
  </section>
</template>

<script lang="ts" setup>
import {
  useCreateRoomSubscriptionMutation,
  useFetchRoomSubscriptionsQuery,
} from '~/graphql'
import { useCurrentUser } from '~/utils/use-current-user'

import { roomInjectionKey } from '../injection-keys'

definePageMeta({
  name: 'room/members',
})

const route = useRoute()
const showUserModal = ref(false)
const currentUser = useCurrentUser()
const currentRoom = inject(roomInjectionKey)
const { executeMutation: createSubscription } =
  useCreateRoomSubscriptionMutation()

// fetch subscriptions
const { data: dataOfSubscriptions, executeQuery: refetchSubscriptions } =
  await useFetchRoomSubscriptionsQuery({
    variables: computed(() => ({
      condition: { roomId: route.params.id as string },
      orderBy: ['SUBSCRIBERS_USERNAME_ASC'],
    })),
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

async function becomeAdmin() {
  const user = toValue(currentUser)
  const room = toValue(currentRoom)
  if (!user) throw new Error('user is not signed in')
  if (!room) throw new Error('room is not available')
  await createSubscription({
    subscription: { roomId: room.id, subscriberId: user.id, role: 'ADMIN' },
  })
  refetchSubscriptions({ requestPolicy: 'cache-and-network' })
}

async function addUserById(id: string) {
  const room = toValue(currentRoom)
  if (!room) throw new Error('room is not available')
  const { data, error } = await createSubscription({
    subscription: { roomId: room.id, subscriberId: id, role: 'MEMBER' },
  })
  refetchSubscriptions({ requestPolicy: 'cache-and-network' })
}
</script>

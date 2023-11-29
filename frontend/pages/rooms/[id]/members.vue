<template>
  <section v-if="!currentRoom">
    <h1>Fehler: Raum konnte nicht vollständig geladen werden.</h1>
  </section>
  <section v-else>
    <h1>Mitglieder</h1>

    <!-- Show option to become admin of orphaned rooms. -->
    <div v-if="currentRoom.nSubscriptions === '0' && currentUser">
      <p>Der Raum hat keine Mitglieder.</p>
      <button @click="becomeAdmin()">
        Ich möchte sein Admin werden.
      </button>
    </div>

    <!-- Show memberships -->
    <div
      v-for="subscription in subscriptions"
      :key="subscription.subscriberId"
      class="subscription"
    >
      <div
        v-if="subscription.subscriber"
        class="subscription__username"
      >
        {{ subscription.subscriber.username }}
      </div>
      <div
        v-else
        class="subscription__username"
      >
        Mitglied unbekannt
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import {
  useCreateRoomSubscriptionMutation,
  useFetchRoomSubscriptionsQuery,
} from "~/graphql";
import { useCurrentUser } from "~/utils/use-current-user";

import { roomInjectionKey } from "../injection-keys";

definePageMeta({
  name: "room/members",
});

const route = useRoute();
const currentUser = useCurrentUser();
const currentRoom = inject(roomInjectionKey);

// fetch subscriptions
const {
  data: dataOfSubscriptions,
  fetching: fetchingSubscriptions,
  executeQuery: refetchSubscriptions,
} = await useFetchRoomSubscriptionsQuery({
  variables: computed(() => ({
    condition: { roomId: route.params.id as string },
    orderBy: ["SUBSCRIBERS_USERNAME_ASC"],
  })),
});

const subscriptions = computed(
  () => dataOfSubscriptions.value?.roomSubscriptions?.nodes ?? []
);

// create subscriptions
const { executeMutation } = useCreateRoomSubscriptionMutation();
async function becomeAdmin() {
  const user = toValue(currentUser);
  const room = toValue(currentRoom);
  if (!user) throw new Error("user is not signed in");
  if (!room) throw new Error("room is not available");
  await executeMutation({
    subscription: { roomId: room.id, subscriberId: user.id, role: "ADMIN" },
  });
  refetchSubscriptions({ requestPolicy: "cache-and-network" });
}
</script>

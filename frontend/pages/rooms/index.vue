<template>
  <article>
    <h1>Räume</h1>
    <section>
      <h1>Neuen Raum anlegen</h1>
      <form @submit.prevent="createRoom">
        <label>
          <span>Neuer Raum:</span>
          <input v-model="nameOfNewRoom">
        </label>
        <button type="submit">
          ok
        </button>
      </form>
    </section>
    <section
      v-for="room in rooms"
      :key="room.id"
      class="room"
    >
      <NuxtLink :to="`/rooms/${room.id}`">
        <h1 v-if="room.title">
          {{ room.title }}
        </h1>
        <h1 v-else>
          Raum {{ room.id.substring(0, 5) }}...
        </h1>
      </NuxtLink>
    </section>
  </article>
</template>

<script lang="ts" setup>
import { computed } from "vue";

import { useCreateRoomMutation,useFetchRoomsQuery } from "~/graphql";

definePageMeta({
  alias: ["/raeume", "/r%C3%A4ume"],
});

// fetch rooms
const { data, executeQuery: refetchRooms } = await useFetchRoomsQuery({});
const rooms = computed(() => data.value?.rooms?.nodes ?? []);

// create room
const nameOfNewRoom = ref("");
const { executeMutation: createRoomMutation } = useCreateRoomMutation();

async function createRoom() {
  const { data, error } = await createRoomMutation({
    room: { title: toValue(nameOfNewRoom) },
  });
  if (data && !error) {
    refetchRooms({ requestPolicy: "cache-and-network" });
    nameOfNewRoom.value = "";
  }
}
</script>

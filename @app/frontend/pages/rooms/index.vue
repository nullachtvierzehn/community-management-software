<template>
  <header class="flex justify-between items-center">
    <h1>Räume</h1>
    <NuxtLink to="/rooms/create" class="btn btn_primary">neu</NuxtLink>
  </header>
  <!--

      <section>
        <h1>Neuen Raum anlegen</h1>
        <form @submit.prevent="createRoom">
          <label>
            <span>Neuer Raum:</span>
            <input v-model="nameOfNewRoom" />
          </label>
          <button type="submit">ok</button>
        </form>
      </section>
    -->
  <section>
    <h1>Liste</h1>
    <NuxtLink
      v-for="room in rooms"
      :key="room.id"
      v-slot="{ navigate }"
      :to="{ name: 'room/about', params: { id: room.id } }"
      custom
    >
      <div class="card cursor-pointer" @click="navigate()">
        <h2 v-if="room.title">
          <NuxtLink :to="{ name: 'room/items', params: { id: room.id } }">{{
            room.title
          }}</NuxtLink>
        </h2>
        <h2 v-else>Raum {{ room.id.substring(0, 5) }}...</h2>
        <p v-if="room.abstract">
          {{ room.abstract }}
        </p>
        <ul>
          <li>{{ room.nSubscriptions }} Mitglieder</li>
          <li>{{ room.nItems }} Nachrichten</li>
          <li v-if="room.mySubscription && room.nItemsSinceLastVisit">
            {{ room.nItemsSinceLastVisit }} Nachrichten seit dem letzten Besuch.
          </li>
        </ul>
      </div>
    </NuxtLink>
  </section>
</template>

<script lang="ts" setup>
import { computed } from 'vue'

import { useCreateRoomMutation, useFetchRoomsQuery } from '~/graphql'

definePageMeta({
  layout: 'page',
  alias: ['/raeume', '/r%C3%A4ume'],
})

// fetch rooms
const { data, executeQuery: refetchRooms } = await useFetchRoomsQuery({})
const rooms = computed(() => data.value?.rooms?.nodes ?? [])

// create room
const nameOfNewRoom = ref('')
const { executeMutation: createRoomMutation } = useCreateRoomMutation()

async function createRoom() {
  const { data, error } = await createRoomMutation({
    room: { title: toValue(nameOfNewRoom) },
  })
  if (data && !error) {
    refetchRooms({ requestPolicy: 'cache-and-network' })
    nameOfNewRoom.value = ''
  }
}
</script>

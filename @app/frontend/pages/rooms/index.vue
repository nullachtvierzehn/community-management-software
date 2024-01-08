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
    <div class="grid gap-4">
      <NuxtLink
        v-for="room in rooms"
        :key="room.id"
        v-slot="{ navigate }"
        :to="{ name: 'room/items', params: { id: room.id } }"
        custom
      >
        <RoomAsListItem
          class="cursor-pointer"
          :model-value="room"
          @click="navigate()"
        />
      </NuxtLink>
    </div>
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

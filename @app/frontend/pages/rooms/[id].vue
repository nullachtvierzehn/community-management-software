<template>
  <template v-if="!room">
    <p>Raum nicht gefunden.</p>
  </template>
  <template v-else>
    <header class="border-b border-gray-300 bg-white shadow drop-shadow-lg">
      <div class="container mx-auto p-0.5">
        <h1 class="my-4 text-3xl font-bold">{{ room.title }}</h1>
        <nav class="flex gap-4 flex-wrap my-4">
          <NuxtLink :to="{ name: 'room/items', params: { id: roomId } }">
            Verlauf
          </NuxtLink>
          <NuxtLink :to="{ name: 'room/members', params: { id: roomId } }">
            Beteiligte
          </NuxtLink>
          <NuxtLink
            class=""
            :to="{ name: 'room/about', params: { id: roomId } }"
          >
            Über
          </NuxtLink>
          <!--

        <NuxtLink :to="{ name: 'room/messages', params: { id: roomId } }">
          Nachrichten
        </NuxtLink>
        <NuxtLink :to="{ name: 'room/materials', params: { id: roomId } }">
          Materialien
        </NuxtLink>
      -->
        </nav>
      </div>
    </header>
    <!-- Room's title -->
    <!--

      <header class="flex justify-between">
        <h1 v-if="room" class="text-2xl font-bold mb-2">
          Raum: {{ room.title }}
        </h1>
        <div id="roomHeaderButtons"></div>
      </header>
    -->

    <!-- Tab -->
    <main>
      <NuxtPage />
    </main>

    <!-- Navigation -->
  </template>
</template>

<script lang="ts" setup>
import { computed, provide, toValue } from 'vue'
import { useRoute } from 'vue-router'

import { useGetRoomQuery } from '~/graphql'

import { roomInjectionKey } from './injection-keys'

definePageMeta({
  alias: ['/raeume/:id', '/r%C3%A4ume/:id'],
})

const route = useRoute()
const roomId = ref(route.params.id as string)
whenever(
  () => route.params.id as string,
  (newId) => (roomId.value = newId)
)

const { data } = await useGetRoomQuery({
  variables: computed(() => ({ id: toValue(roomId) })),
  pause: logicNot(roomId),
})

const room = computed(() => (route.params.id ? data.value?.room : undefined))

provide(roomInjectionKey, room)
</script>

<style lang="postcss" scoped>
article {
  display: grid;
  grid-template:
    'header' auto
    'main' 1fr
    'footer' auto
    / 1fr;
}

nav {
  grid-area: footer;

  & main {
    overflow: scroll;
  }

  & a[href] {
    @apply block px-4 py-1 bg-gray-200 rounded-full;
  }

  & a[href].router-link-active {
    @apply bg-gray-600 text-white shadow-lg;
  }
}
</style>

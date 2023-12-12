<template>
  <article
    class="grid box-border m-4 p-4 bg-gray-200 rounded-xl h-[calc(100vh-2*theme(space.4))]"
  >
    <!-- Room's title -->
    <header class="flex justify-between">
      <h1 v-if="room" class="text-2xl font-bold mb-2">
        Raum: {{ room.title }}
      </h1>
      <div id="roomHeaderButtons"></div>
    </header>

    <!-- Tab -->
    <main class="overflow-scroll">
      <NuxtPage />
    </main>

    <!-- Navigation -->

    <nav
      class="border-0 border-slate-200 border-t-2 -m-4 p-4 mt-4 flex gap-4 flex-wrap"
    >
      <NuxtLink class="" :to="{ name: 'room/about', params: { id: roomId } }">
        Über
      </NuxtLink>
      <NuxtLink :to="{ name: 'room/members', params: { id: roomId } }">
        Mitglieder
      </NuxtLink>
      <NuxtLink :to="{ name: 'room/messages', params: { id: roomId } }">
        Nachrichten
      </NuxtLink>
      <NuxtLink :to="{ name: 'room/materials', params: { id: roomId } }">
        Materialien
      </NuxtLink>
      <NuxtLink :to="{ name: 'room/items', params: { id: roomId } }">
        Inhalte
      </NuxtLink>
    </nav>
  </article>
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

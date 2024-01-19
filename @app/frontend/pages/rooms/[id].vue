<template>
  <template v-if="!room">
    <NuxtLayout name="page">
      <h1>Kein Raum zu sehen</h1>
      <template v-if="!user">
        <p>
          Möglicherweise ist er nur für Mitglieder sichtbar. Logge Dich bitte
          ein.
        </p>
        <NuxtLink
          :to="{ name: 'login', query: { next: route.fullPath } }"
          class="btn btn_primary"
          >Einloggen</NuxtLink
        >
      </template>
      <template v-else>
        <p>
          Vielleicht gibt es ihn nicht. Möglicherweise ist er aber auch privat
          und nur auf Einladung sichtbar. Schreibe bitte an
          <a href="mailto:mail@a-friend.org">mail@a-friend.org</a>, damit wir
          helfen können.
        </p>
      </template>
    </NuxtLayout>
  </template>
  <template v-else>
    <template
      v-if="route.meta.layout === 'page' || route.meta.renderAsTopLevelRoute"
    >
      <NuxtPage />
    </template>
    <template v-else>
      <!-- global header -->
      <div class="bg-gray-200 p-4">
        <div class="container mx-auto flex justify-between items-center">
          <NuxtLink to="/"
            ><img
              src="/logo-schwarz.svg"
              width="140"
              alt="Logo mit Link zur Startseite"
          /></NuxtLink>
          <div class="flex gap-4">
            <NuxtLink to="/">Startseite</NuxtLink>
            <NuxtLink to="/profile">Mein Account</NuxtLink>
          </div>
        </div>
      </div>

      <header
        class="border-b border-gray-300 bg-white shadow drop-shadow-lg p-4"
      >
        <!-- room header -->
        <div class="container mx-auto p-0.5">
          <h1 class="mb-4 text-3xl font-bold">{{ room.title }}</h1>

          <!-- Navigation -->
          <nav class="flex gap-4 flex-wrap">
            <NuxtLink
              :to="{ name: 'room/items', params: { id: roomId } }"
              replace
            >
              Verlauf
            </NuxtLink>
            <NuxtLink
              :to="{ name: 'room/members', params: { id: roomId } }"
              replace
            >
              Beteiligte
            </NuxtLink>
            <NuxtLink
              replace
              class=""
              :to="{ name: 'room/about', params: { id: roomId } }"
            >
              Über
            </NuxtLink>
          </nav>
        </div>
      </header>

      <!-- Tab -->
      <main class="p-4">
        <NuxtPage />
      </main>
    </template>
  </template>
</template>

<script lang="ts" setup>
import { useRoute } from 'vue-router'

definePageMeta({
  alias: ['/raeume/:id', '/r%C3%A4ume/:id'],
})

const route = useRoute()
const user = await useCurrentUser()

const roomId = ref(route.params.id as string)
whenever(
  () => route.params.id as string,
  (newId) => (roomId.value = newId)
)

const { room } = await useRoom({ id: roomId })
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

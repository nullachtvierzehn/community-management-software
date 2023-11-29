<template>
  <h1 v-if="room">
    Raum: {{ room.title }}
  </h1>
  <NuxtLink :to="{ name: 'room/about' }">
    Über
  </NuxtLink>
  <NuxtLink :to="{ name: 'room/members' }">
    Mitglieder
  </NuxtLink>
  <NuxtLink :to="{ name: 'room/messages' }">
    Nachrichten
  </NuxtLink>
  <NuxtLink :to="{ name: 'room/materials' }">
    Materialien
  </NuxtLink>
  <NuxtPage />
</template>

<script lang="ts" setup>
import { computed, type InjectionKey,provide, toValue } from "vue";
import { useRoute } from "vue-router";

import { useGetRoomQuery } from "~/graphql";

import { roomInjectionKey } from "./injection-keys";

definePageMeta({
  alias: ["/raeume/:id", "/r%C3%A4ume/:id"],
});

const route = useRoute();

const { data, fetching } = await useGetRoomQuery({
  variables: computed(() => ({ id: toValue(route.params.id) as string })),
});

const room = computed(() => data.value?.room);

provide(roomInjectionKey, room);
</script>

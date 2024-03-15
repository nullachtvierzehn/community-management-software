<template>
  <header class="flex justify-between items-center">
    <h1>Spaces</h1>
    <NuxtLink to="/spaces/create" class="btn btn_primary">neu</NuxtLink>
  </header>
  <section>
    <NuxtLink
      v-for="space in spaces"
      :key="space.id"
      :to="{ name: 'space/by-id', params: { id: space.id } }"
    >
      {{ space.name }}
    </NuxtLink>
  </section>
</template>

<script setup lang="ts">
import { useFetchSpacesQuery } from '~/graphql'

definePageMeta({
  layout: 'page',
  alias: ['/spaces'],
})

const { data } = await useFetchSpacesQuery({
  variables: {
    orderBy: ['NAME_ASC'],
  },
  requestPolicy: 'cache-and-network',
})

const spaces = computed(() => data.value?.spaces?.nodes ?? [])
</script>

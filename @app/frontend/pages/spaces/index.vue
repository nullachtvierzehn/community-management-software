<template>
  <header class="flex justify-between items-center">
    <h1>Spaces</h1>
    <NuxtLink to="/spaces/create" class="btn btn_primary">neu</NuxtLink>
  </header>
  <section>
    <h1>Liste</h1>
    <div class="grid gap-4">
      <NuxtLink
        v-for="space in spaces"
        :key="space.id"
        v-slot="{ navigate }"
        :to="{ name: 'space/items', params: { id: space.id } }"
        custom
      >
        <SpaceAsListItem
          class="cursor-pointer"
          :model-value="space"
          @click="navigate()"
        />
      </NuxtLink>
    </div>
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
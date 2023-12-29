<template>
  <header class="flex justify-between items-center">
    <h1>Themen</h1>
    <NuxtLink to="/topics/create" class="btn btn_primary">neu</NuxtLink>
  </header>

  <section name="topics">
    <h1>Liste</h1>
    <NuxtLink
      v-for="topic in topics"
      :key="topic.id"
      v-slot="{ navigate }"
      :to="{ name: 'topic/show', params: { slug: topic.slug } }"
      custom
    >
      <div class="card cursor-pointer" @click="navigate()">
        <h2>{{ topic.title ?? topic.slug ?? topic.id }}</h2>
      </div>
    </NuxtLink>
  </section>
</template>

<script lang="ts" setup>
import { useFetchTopicsQuery } from '~/graphql'

definePageMeta({
  layout: 'page',
  alias: ['/themen'],
})

const { data: dataOfTopics } = await useFetchTopicsQuery({
  variables: {
    orderBy: ['TITLE_ASC'],
  },
})

const topics = computed(() => dataOfTopics.value?.topics?.nodes ?? [])
</script>

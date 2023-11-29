<template>
  <article>
    <h1>Themen</h1>
    <ul>
      <li
        v-for="topic in topics"
        :key="topic.id"
      >
        {{ topic.title ?? topic.slug ?? topic.id }}
      </li>
    </ul>
  </article>
</template>

<script lang="ts" setup>
import { useFetchTopicsQuery } from "~/graphql";

definePageMeta({
  alias: ["/themen"],
});

const { data: dataOfTopics } = await useFetchTopicsQuery({
  variables: {
    orderBy: ["TITLE_ASC"],
  },
});

const topics = computed(() => dataOfTopics.value?.topics?.nodes ?? []);
</script>

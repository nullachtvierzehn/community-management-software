<template>
  <h1>Hallo {{ currentUser }}</h1>
</template>

<script setup lang="ts">
import { useCurrentUserQuery } from "../graphql";
import { computed } from "vue";

const { data } = await useCurrentUserQuery({});
const currentUser = computed(() => data.value?.currentUser);
</script>

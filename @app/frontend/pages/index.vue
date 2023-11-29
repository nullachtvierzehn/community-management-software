<template>
  <h1>Hallo {{ currentUser }}</h1>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import { useCurrentUserQuery } from '../graphql'

const { data } = await useCurrentUserQuery({})
const currentUser = computed(() => data.value?.currentUser)
</script>

<template>
  <div>{{ $route.params.something }}</div>
  <NuxtLink to="/test/something-else">something else</NuxtLink>
</template>

<script lang="ts" setup>
await 5
</script>

<template>
  <section>
    <h1>Über</h1>
    <p>{{ room }}</p>
  </section>
</template>

<script lang="ts" setup>
definePageMeta({
  name: 'room/about',
})

const room = inject('room') as any
</script>

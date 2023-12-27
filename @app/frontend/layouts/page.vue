<template>
  <article class="container mx-auto p-4">
    <slot></slot>
  </article>
</template>

<style lang="postcss" scoped>
article :deep(h1) {
  @apply text-4xl font-bold mb-4;
}
</style>

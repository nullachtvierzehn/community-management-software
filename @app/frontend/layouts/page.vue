<template>
  <article class="container mx-auto p-4">
    <slot></slot>
  </article>
</template>

<style lang="postcss" scoped>
article :deep(h1) {
  @apply text-4xl font-bold mb-4;
}

article :deep(h2) {
  @apply text-3xl font-bold mb-3;
}

article :deep(h3) {
  @apply text-2xl font-bold mb-2;
}

article :deep(section h1) {
  @apply text-3xl font-bold mb-4;
}

article :deep(section h2) {
  @apply text-2xl font-bold mb-3;
}

article :deep(section h3) {
  @apply text-xl font-bold mb-2;
}

article :deep(p) {
  @apply my-4;
}
</style>

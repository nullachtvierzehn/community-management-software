<template>
  <article>
    <slot name="header">
      <header class="bg-gray-200 mb-3">
        <div class="container mx-auto p-4 flex justify-between items-center">
          <NuxtLink to="/"
            ><img
              src="/logo-schwarz.svg"
              width="140"
              alt="Logo mit Link zur Startseite"
          /></NuxtLink>
          <nav class="flex gap-4">
            <NuxtLink to="/">Startseite</NuxtLink>
            <NuxtLink to="/profile">Mein Account</NuxtLink>
          </nav>
        </div>
      </header>
    </slot>
    <main class="container mx-auto p-4">
      <slot></slot>
    </main>
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

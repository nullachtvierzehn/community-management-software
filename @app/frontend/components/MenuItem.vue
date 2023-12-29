<template>
  <button
    v-if="action"
    type="button"
    class="tiptap-editor__menu-item"
    :class="{ 'is-active': isActive ? isActive() : null }"
    :title="title"
    @click="action"
  >
    <svg class="remix">
      <use :xlink:href="`${remixiconUrl}#ri-${icon}`" />
    </svg>
  </button>
</template>

<script setup lang="ts">
import remixiconUrl from 'remixicon/fonts/remixicon.symbol.svg'

defineProps<{
  type?: undefined
  icon: string
  title: string
  action: () => void
  isActive?: () => boolean | null | undefined
}>()
</script>

<style lang="css">
.tiptap-editor__menu-item {
  background: transparent;
  border: none;
  border-radius: 0.4rem;
  color: #fff;
  cursor: pointer;
  height: 1.75rem;
  padding: 0.25rem;
  margin-right: 0.25rem;
  width: 1.75rem;
}

.tiptap-editor__menu-item svg {
  fill: currentColor;
  height: 100%;
  width: 100%;
}

.tiptap-editor__menu-item.is-active,
.tiptap-editor__menu-item:hover {
  background-color: #303030;
}
</style>

<!-- eslint-disable vue/no-v-html -->
<template>
  <div v-html="html" />
</template>

<script setup lang="ts">
import { type Extensions } from '@tiptap/core'
import DropCursorExtension from '@tiptap/extension-dropcursor'
import ImageExtension from '@tiptap/extension-image'
import LinkExtension from '@tiptap/extension-link'
import { generateHTML } from '@tiptap/html'
import StarterKit from '@tiptap/starter-kit'
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    content: object
    extensions?: Extensions
  }>(),
  {
    extensions: () => [
      StarterKit,
      ImageExtension,
      DropCursorExtension,
      LinkExtension,
    ],
  }
)

const html = computed(() => generateHTML(props.content, props.extensions))
</script>

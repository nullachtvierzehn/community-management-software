<template>
  <div v-html="html" />
</template>

<script setup lang="ts">
import StarterKit from "@tiptap/starter-kit";
import ImageExtension from "@tiptap/extension-image";
import DropCursorExtension from "@tiptap/extension-dropcursor";
import { generateHTML } from "@tiptap/html";
import { type Extensions } from "@tiptap/core";
import LinkExtension from "@tiptap/extension-link";
import { computed } from "vue";

const props = withDefaults(
  defineProps<{
    content: object;
    extensions?: Extensions;
  }>(),
  {
    extensions: () => [
      StarterKit,
      ImageExtension,
      DropCursorExtension,
      LinkExtension,
    ],
  }
);

const html = computed(() => generateHTML(props.content, props.extensions));
</script>

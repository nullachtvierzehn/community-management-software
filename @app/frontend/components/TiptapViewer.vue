<!-- eslint-disable vue/no-v-html -->
<template>
  <div v-html="html" />
</template>

<script setup lang="ts">
import { type JSONContent } from "@tiptap/core";
import ImageExtension from "@tiptap/extension-image";
import LinkExtension from "@tiptap/extension-link";
import { generateHTML } from "@tiptap/html";
import StarterKit from "@tiptap/starter-kit";
import { computed } from "vue";

const props = defineProps<{
  content: JSONContent;
}>();

const html = computed(() =>
  generateHTML(props.content, [
    StarterKit,
    ImageExtension,
    //DropCursorExtension,
    LinkExtension,
  ]),
);
</script>

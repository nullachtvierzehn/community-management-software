<template>
  <div class="tiptap-editor">
    <slot name="menu" v-bind:editor="editor">
      <menu-bar :editor="editor" />
    </slot>
    <editor-content :editor="editor" />
  </div>
</template>

<style>
.tiptap-editor {
  border: 2px solid black;
  border-radius: 0.5rem;
  overflow: hidden;
}
</style>

<script lang="ts" setup>
import {
  useEditor,
  EditorContent,
  type JSONContent,
  type HTMLContent,
} from "@tiptap/vue-3";
import StarterKit from "@tiptap/starter-kit";
import ImageExtension from "@tiptap/extension-image";
import DropCursorExtension from "@tiptap/extension-dropcursor";
import LinkExtension from "@tiptap/extension-link";

const props = defineProps<
  { json: JSONContent; html?: null } | { json?: null; html: HTMLContent }
>();

const emit = defineEmits<{
  (e: "update:json", value: JSONContent): void;
  (e: "update:html", value: HTMLContent): void;
}>();

const editor = useEditor({
  extensions: [StarterKit, ImageExtension, DropCursorExtension, LinkExtension],
  content: props.json ?? props.html,
  onUpdate({ editor }) {
    console.log("update!!!!", editor.getHTML());
    emit("update:json", editor.getJSON());
    emit("update:html", editor.getHTML());
  },
});
</script>

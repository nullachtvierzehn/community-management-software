<template>
  <div class="tiptap-editor">
    <slot
      name="menu"
      :editor="editor"
    >
      <menu-bar :editor="editor" />
    </slot>
    <editor-content :editor="editor" />
  </div>
</template>

<script lang="ts" setup>
import DropCursorExtension from "@tiptap/extension-dropcursor";
import ImageExtension from "@tiptap/extension-image";
import LinkExtension from "@tiptap/extension-link";
import StarterKit from "@tiptap/starter-kit";
import {
  EditorContent,
  type HTMLContent,
  type JSONContent,
  useEditor,
} from "@tiptap/vue-3";

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

<style>
.tiptap-editor {
  border: 2px solid black;
  border-radius: 0.5rem;
  overflow: hidden;
}
</style>

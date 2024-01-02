<template>
  <div class="tiptap-editor">
    <slot name="menu" :editor="editor">
      <menu-bar :editor="editor" />
    </slot>
    <editor-content ref="editorElement" :editor="editor" />
  </div>
</template>

<script lang="ts" setup>
import ImageExtension from '@tiptap/extension-image'
import LinkExtension from '@tiptap/extension-link'
import StarterKit from '@tiptap/starter-kit'
import {
  EditorContent,
  type HTMLContent,
  type JSONContent,
  useEditor,
} from '@tiptap/vue-3'
import { useField } from 'vee-validate'

const props = defineProps<
  { name: string } & (
    | { json: JSONContent; html?: null }
    | { json?: null; html: HTMLContent }
  )
>()

const editorElement = ref<HTMLElement>()
const { handleBlur, handleChange } = useField(() => props.name)

const emit = defineEmits<{
  (e: 'update:json', value: JSONContent): void
  (e: 'update:html', value: HTMLContent): void
}>()

const editor = useEditor({
  extensions: [
    StarterKit,
    ImageExtension,
    //DropCursorExtension,
    LinkExtension,
  ],
  content: props.json ?? props.html,
  onUpdate({ editor }) {
    if (props.json) {
      const json = editor.getJSON()
      emit('update:json', json)
      handleChange(json)
    }
    if (props.html) {
      const html = editor.getHTML()
      emit('update:html', html)
      handleChange(html)
    }
  },
  onBlur({ event }) {
    handleBlur(event)
  },
})
</script>

<style>
:where(.tiptap-editor) {
  border: 2px solid black;
  border-radius: 0.5rem;
  overflow: hidden;
}
</style>

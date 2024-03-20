<template>
  <div class="tiptap-editor">
    <slot name="menu" :editor="editor">
      <menu-bar :editor="editor" :actions="actions" />
    </slot>
    <editor-content
      ref="editorElement"
      :editor="editor"
      class="tiptap-editor__content"
    />
  </div>
</template>

<script lang="ts" setup>
import type { EditorEvents } from '@tiptap/core'
import ImageExtension from '@tiptap/extension-image'
import LinkExtension from '@tiptap/extension-link'
import StarterKit from '@tiptap/starter-kit'
import { EditorContent, type JSONContent, useEditor } from '@tiptap/vue-3'

const props = defineProps<{
  actions?: string[]
  json: JSONContent
}>()

const emit = defineEmits<{
  (e: 'update:json', value: JSONContent): void
  (e: 'blur', value: EditorEvents['blur']): void
}>()

const editorElement = ref<HTMLElement>()

const editor = useEditor({
  extensions: [
    StarterKit,
    ImageExtension,
    //DropCursorExtension,
    LinkExtension,
  ],
  content: props.json,
  onUpdate({ editor }) {
    if (props.json) {
      const json = editor.getJSON()
      emit('update:json', json)
    }
  },
  onBlur(blurEvent) {
    emit('blur', blurEvent)
  },
})

watch(
  () => props.json,
  (json, oldJson) => {
    if (json !== oldJson) editor.value?.commands.setContent(json, false)
  }
)
</script>

<style>
:where(.tiptap-editor) {
  border: 2px solid black;
  border-radius: 0.5rem;
  overflow: hidden;
}

:where(.tiptap-editor__content > .tiptap) {
  min-height: 4rem;
}
</style>

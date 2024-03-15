<template>
  <div class="wrapped-tiptap-editor">
    <TiptapEditor
      :json="props.json"
      @update:json="handleChange($event)"
      @blur="handleBlur($event)"
    >
      <template #menu>
        <slot name="menu"></slot>
      </template>
    </TiptapEditor>
    <slot name="error">
      <div
        v-show="meta.touched || errorMessage"
        class="wrapped-tiptap-editor wrapped-tiptap-editor__error"
      >
        {{ errorMessage }}
      </div>
    </slot>
  </div>
</template>

<script lang="ts" setup>
import { type EditorEvents, type JSONContent } from '@tiptap/vue-3'
import { useField } from 'vee-validate'

const props = defineProps<{
  name: string
  actions?: string[]
  json: JSONContent
}>()

const emit = defineEmits<{
  (e: 'update:json', value: JSONContent): void
  (e: 'blur', value: EditorEvents['blur']): void
}>()

// about building custom inputs: https://vee-validate.logaretm.com/v4/examples/custom-inputs/
const {
  handleBlur: handleBlurInTipTap,
  handleChange: handleChangeInTipTap,
  meta,
  errorMessage,
} = useField(toRef(props, 'name'), undefined, {
  initialValue: props.json,
})

function handleChange(value: JSONContent) {
  handleChangeInTipTap(value)
  emit('update:json', value)
}

function handleBlur(value: EditorEvents['blur']) {
  handleBlurInTipTap(value.event, true)
  emit('blur', value)
}
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

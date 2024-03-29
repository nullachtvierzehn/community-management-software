<template>
  <div class="tiptap-editor__menu-bar">
    <slot name="firstButtons" />
    <div
      v-for="(section, i) in selectedItems"
      :key="`section-${i}`"
      class="tiptap-editor__menu-section"
    >
      <menu-item
        v-for="(item, j) in section"
        :key="`button-${i}-${j}`"
        v-bind="item"
      />
    </div>
    <slot name="lastButtons" />
  </div>
</template>

<script setup lang="ts">
import { Editor } from '@tiptap/vue-3'
import { ref } from 'vue'

const props = defineProps<{
  editor?: Editor
  actions?: string[]
}>()

const items = ref<
  {
    type?: undefined
    icon: string
    title: string
    action: () => void
    isActive?: () => boolean | null | undefined
  }[][]
>([
  [
    {
      icon: 'bold',
      title: 'Bold',
      action: () => props.editor?.chain().focus().toggleBold().run(),
      isActive: () => props.editor?.isActive('bold'),
    },
    {
      icon: 'italic',
      title: 'Italic',
      action: () => props.editor?.chain().focus().toggleItalic().run(),
      isActive: () => props.editor?.isActive('italic'),
    },
    {
      icon: 'strikethrough',
      title: 'Strike',
      action: () => props.editor?.chain().focus().toggleStrike().run(),
      isActive: () => props.editor?.isActive('strike'),
    },
    {
      icon: 'link',
      title: 'Link',
      action() {
        if (!props.editor) return
        const previousUrl = props.editor.getAttributes('link').href
        const url = window.prompt('URL', previousUrl)

        // cancelled
        if (url === null) {
          return
        }

        // empty
        if (url === '') {
          props.editor.chain().focus().extendMarkRange('link').unsetLink().run()

          return
        }

        // update link
        props.editor
          .chain()
          .focus()
          .extendMarkRange('link')
          .setLink({ href: url })
          .run()
      },
      isActive: () => props.editor?.isActive('link'),
    },
    {
      icon: 'code-view',
      title: 'Code',
      action: () => props.editor?.chain().focus().toggleCode().run(),
      isActive: () => props.editor?.isActive('code'),
    },
  ],
  /*
        {
          icon: 'mark-pen-line',
          title: 'Highlight',
          action: () => props.editor?.chain().focus().toggleHighlight().run(),
          isActive: () => props.editor?.isActive('highlight'),
        },
        */
  [
    {
      icon: 'h-1',
      title: 'Heading 1',
      action: () =>
        props.editor?.chain().focus().toggleHeading({ level: 1 }).run(),
      isActive: () => props.editor?.isActive('heading', { level: 1 }),
    },
    {
      icon: 'h-2',
      title: 'Heading 2',
      action: () =>
        props.editor?.chain().focus().toggleHeading({ level: 2 }).run(),
      isActive: () => props.editor?.isActive('heading', { level: 2 }),
    },
    {
      icon: 'paragraph',
      title: 'Paragraph',
      action: () => props.editor?.chain().focus().setParagraph().run(),
      isActive: () => props.editor?.isActive('paragraph'),
    },
    {
      icon: 'list-unordered',
      title: 'Bullet List',
      action: () => props.editor?.chain().focus().toggleBulletList().run(),
      isActive: () => props.editor?.isActive('bulletList'),
    },
    {
      icon: 'list-ordered',
      title: 'Ordered List',
      action: () => props.editor?.chain().focus().toggleOrderedList().run(),
      isActive: () => props.editor?.isActive('orderedList'),
    },
    /*
        {
          icon: 'list-check-2',
          title: 'Task List',
          action: () => props.editor?.chain().focus().toggleTaskList().run(),
          isActive: () => props.editor?.isActive('taskList'),
        },
        {
          icon: 'code-box-line',
          title: 'Code Block',
          action: () => props.editor?.chain().focus().toggleCodeBlock().run(),
          isActive: () => props.editor?.isActive('codeBlock'),
        },
        */
  ],
  [
    {
      icon: 'double-quotes-l',
      title: 'Blockquote',
      action: () => props.editor?.chain().focus().toggleBlockquote().run(),
      isActive: () => props.editor?.isActive('blockquote'),
    },
    {
      icon: 'separator',
      title: 'Horizontal Rule',
      action: () => props.editor?.chain().focus().setHorizontalRule().run(),
    },
  ],
  [
    {
      icon: 'text-wrap',
      title: 'Hard Break',
      action: () => props.editor?.chain().focus().setHardBreak().run(),
    },
    {
      icon: 'format-clear',
      title: 'Clear Format',
      action: () =>
        props.editor?.chain().focus().clearNodes().unsetAllMarks().run(),
    },
  ],
  [
    {
      icon: 'arrow-go-back-line',
      title: 'Undo',
      action: () => props.editor?.chain().focus().undo().run(),
    },
    {
      icon: 'arrow-go-forward-line',
      title: 'Redo',
      action: () => props.editor?.chain().focus().redo().run(),
    },
  ],
])

const selectedItems = computed(() =>
  props.actions
    ? items.value.map((section) =>
        section.filter((action) => props.actions?.includes(action.icon))
      )
    : items.value
)
</script>

<style lang="postcss">
:where(.tiptap-editor__menu-bar) {
  @apply flex flex-wrap;
}
</style>

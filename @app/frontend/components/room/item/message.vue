<template>
  <!---->
  <RoomItemMessageEditor
    v-if="showEditor"
    :model-value="modelValue"
    @saved="internalEdit = false"
  >
    <template v-if="$slots.floatingMenuContents" #contextMenuButton>
      <slot name="contextMenuButton" v-bind="slotProperties">
        <button ref="anchor1" @click="showFloatingMenu = !showFloatingMenu">
          <i class="ri-more-2-line select-none"></i>
        </button>
      </slot>
    </template>
  </RoomItemMessageEditor>
  <RoomItemMessageViewer
    v-else
    :model-value="modelValue"
    @respond="emit('respond', $event)"
    @go-to-parent="emit('goToParent', $event)"
  >
    <template v-if="$slots.floatingMenuContents" #contextMenuButton>
      <slot name="contextMenuButton" v-bind="slotProperties">
        <button ref="anchor2" @click="showFloatingMenu = !showFloatingMenu">
          <i class="ri-more-2-line select-none"></i>
        </button>
      </slot>
    </template>
  </RoomItemMessageViewer>
  <slot name="contextMenu">
    <div
      v-if="showFloatingMenu"
      ref="floatingMenu"
      :style="floatingMenuStyles"
      v-bind="slotProperties"
    >
      <slot name="floatingMenuContents" v-bind="slotProperties"></slot>
    </div>
  </slot>
</template>

<script setup lang="ts">
import { flip, shift, useFloating } from '@floating-ui/vue'
import { onClickOutside, useEventListener } from '@vueuse/core'

import { type RoomItemAsListItemFragment } from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
  edit?: boolean
}>()

const emit = defineEmits<{
  (e: 'respond', item: RoomItemAsListItemFragment): void
  (e: 'goToParent', item: { id: string }): void
  (e: 'update:edit', value?: boolean): void
}>()

const user = await useCurrentUser()

const floatingMenu = ref<HTMLDivElement | null>(null)
const showFloatingMenu = ref(false)
const isByCurrentUser = computed(
  () => user.value?.id && props.modelValue.contributor?.id === user.value.id
)
const isDraft = computed(() => props.modelValue.contributedAt === null)
const internalEdit = useVModel(props, 'edit', undefined, { passive: true })
const showEditor = computed(
  () => isByCurrentUser.value && (isDraft.value || internalEdit.value === true)
)
const anchor1 = ref<HTMLButtonElement | null>(null)
const anchor2 = ref<HTMLButtonElement | null>(null)
const anchor = computed(() => {
  return showEditor.value ? anchor1.value : anchor2.value
})

const slotProperties = reactive({
  isDraft,
  isByCurrentUser,
  showEditor,
  edit: internalEdit,
  showFloatingMenu,
  toggleFloatingMenu: () => {
    showFloatingMenu.value = !showFloatingMenu.value
  },
  toggleEdit: () => {
    internalEdit.value = !internalEdit.value
  },
})

const { floatingStyles: floatingMenuStyles, update: repositionFloatingMenu } =
  useFloating(anchor, floatingMenu, {
    placement: 'bottom-end',
    middleware: [flip(), shift()],
    open: showFloatingMenu,
  })

useEventListener('resize', repositionFloatingMenu)

onClickOutside(
  floatingMenu,
  () => {
    showFloatingMenu.value = false
  },
  { ignore: [anchor1, anchor2] }
)
</script>

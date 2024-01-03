<template>
  <div>
    <div class="flex mb-2 justify-between">
      <!-- user profile -->
      <UserName :profile="modelValue.contributor" class="font-bold" />

      <!-- contribution date -->
      <div v-if="modelValue.contributedAt" class="italic">
        {{ $dayjs(modelValue.contributedAt).fromNow() }}
      </div>
      <div v-else class="italic">Entwurf</div>
    </div>

    <!-- message body -->
    <tiptap-viewer :content="modelValue.messageBody" />

    <!-- Answered message -->
    <div
      v-if="modelValue.parent"
      class="bg-gray-300 p-2 rounded-md my-4 block"
      @click="emit('goToParent', modelValue.parent)"
    >
      Als Antwort auf
      <user-name
        :profile="modelValue.parent?.contributor"
        tag="span"
      />&nbsp;<span v-if="modelValue.parent.contributedAt">{{
        formatDateFromNow(modelValue.parent.contributedAt)
      }}</span>
      <span v-else>(noch im Entwurf)</span>
    </div>

    <!-- actions -->
    <div v-if="internalShowActions" class="btn-bar mt-4 justify-end">
      <button class="btn btn_primary" @click="emit('respond', modelValue)">
        antworten
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

const emit = defineEmits<{
  (e: 'respond', item: RoomItemAsListItemFragment): void
  (e: 'goToParent', item: { id: string }): void
}>()

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
  showActions?: boolean
}>()

const internalShowActions = useVModel(props, 'showActions', emit, {
  passive: true,
})
</script>

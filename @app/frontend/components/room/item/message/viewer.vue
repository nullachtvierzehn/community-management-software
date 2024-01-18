<template>
  <div>
    <div class="flex mb-2 justify-between">
      <!-- user profile -->
      <UserName :profile="modelValue.contributor" class="font-bold" />

      <!-- contribution date -->
      <div class="flex gap-2">
        <div v-if="modelValue.contributedAt" class="italic">
          {{ $dayjs(modelValue.contributedAt).fromNow() }}
        </div>
        <div v-else class="italic">Entwurf</div>
        <slot name="contextMenuButton"></slot>
      </div>
    </div>

    <!-- message body -->
    <tiptap-viewer :content="modelValue.messageBody" />

    <!-- attachments -->
    <div v-if="attachments.length">
      <template v-for="attachment in attachments" :key="attachment.id">
        <div class="relative">
          <div
            v-if="attachment.topic"
            class="bg-green-300 p-2 overflow-hidden rounded-md shadow-md max-h-32"
          >
            <NuxtLink
              :to="{
                name: 'topic/show',
                params: { slug: attachment.topic?.slug.split('/') },
              }"
            >
              <tiptap-viewer
                v-if="attachment.topic.contentPreview"
                class="room-item__content room-item__topic"
                :content="attachment.topic.contentPreview"
              />
            </NuxtLink>
          </div>
        </div>
      </template>
    </div>

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

const attachments = computed(
  () => props.modelValue.roomItemAttachments.nodes ?? []
)

const internalShowActions = useVModel(props, 'showActions', emit, {
  passive: true,
})
</script>

<template>
  <div class="room-item message">
    <div class="flex mb-2 justify-between">
      <!-- user profile -->
      <UserName
        :profile="modelValue.contributor"
        class="font-bold room-item__contributor"
      />

      <!-- contribution date -->
      <div
        v-if="modelValue.contributedAt"
        class="italic room-item__contribution-date"
      >
        {{ $dayjs(modelValue.contributedAt).fromNow() }}
      </div>
    </div>

    <!-- message body -->
    <tiptap-viewer
      class="room-item__content room-item__message"
      :content="modelValue.messageBody"
    />
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()
</script>

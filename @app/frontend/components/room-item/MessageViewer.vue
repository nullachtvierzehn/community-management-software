<template>
  <div class="room-item message">
    <!-- user profile -->
    <UserName
      :profile="modelValue.contributor"
      class="room-item__contributor"
    />

    <!-- contribution date -->
    <div v-if="modelValue.contributedAt" class="room-item__contribution-date">
      {{ $dayjs(modelValue.contributedAt).fromNow() }}
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

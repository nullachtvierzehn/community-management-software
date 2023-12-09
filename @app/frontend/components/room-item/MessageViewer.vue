<template>
  <div class="room-item message">
    <!-- user profile -->
    <UserName
      :profile="modelValue.contributor"
      class="room-item__contributor"
    />

    <!-- contribution date -->
    <div v-if="modelValue.contributedAt" class="room-item__contribution-date">
      {{ formatDateFromNow(modelValue.contributedAt) }}
    </div>

    <!-- message body -->
    <tiptap-viewer :content="modelValue.messageBody" />
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()
</script>

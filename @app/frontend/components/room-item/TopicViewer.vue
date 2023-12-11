<template>
  <div class="room-item">
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
    <tiptap-viewer
      v-if="modelValue.topic?.contentTeaser"
      class="room-item__content room-item__topic"
      :content="modelValue.topic.contentTeaser"
    />
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()
</script>

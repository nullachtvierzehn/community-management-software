<template>
  <div class="room-item">
    <!-- message body -->
    <div class="bg-green-300 p-2 overflow-hidden rounded-md shadow-md max-h-32">
      <NuxtLink
        :to="{
          name: 'topic/show',
          params: { slug: modelValue.topic?.slug.split('/') },
        }"
      >
        <tiptap-viewer
          v-if="modelValue.topic?.contentPreview"
          class="room-item__content room-item__topic"
          :content="modelValue.topic.contentPreview"
        />
      </NuxtLink>
    </div>

    <div class="flex mt-2 justify-between">
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
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()
</script>

<style lang="postcss" scoped>
.room-item__topic {
  font-size: 0.7rem;
  line-height: 1.3;
}

.room-item__topic :deep(h1, h2, h3, h4, h5, h6) {
  @apply font-semibold;
}

.room-item__topic :deep(h1) {
  font-size: 1.4em;
}

.room-item__topic :deep(h2) {
  font-size: 1.3em;
}

.room-item__topic :deep(h3, h4) {
  font-size: 1.15em;
}

.room-item__topic :deep(h5, h6) {
  font-size: 1em;
}
</style>

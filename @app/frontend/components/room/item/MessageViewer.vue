<template>
  <div>
    <div class="flex mb-2 justify-between">
      <!-- user profile -->
      <UserName :profile="modelValue.contributor" class="font-bold" />

      <!-- contribution date -->
      <div v-if="modelValue.contributedAt" class="italic">
        {{ $dayjs(modelValue.contributedAt).fromNow() }}
      </div>
    </div>

    <!-- message body -->
    <tiptap-viewer class="" :content="modelValue.messageBody" />
  </div>
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const currentUser = await useCurrentUser()
const byCurrentuser = computed(
  () =>
    (currentUser.value &&
      props.modelValue.contributor?.id === currentUser.value?.id) ??
    false
)
</script>

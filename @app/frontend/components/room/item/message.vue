<template>
  <!---->
  <RoomItemMessageEditor
    v-if="isByCurrentUser && isDraft"
    key="one"
    :model-value="modelValue"
  />
  <RoomItemMessageViewer
    v-else
    key="two"
    :model-value="modelValue"
    @respond="emit('respond', $event)"
    @go-to-parent="emit('goToParent', $event)"
  />
</template>

<script setup lang="ts">
import { type RoomItemAsListItemFragment } from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const emit = defineEmits<{
  (e: 'respond', item: RoomItemAsListItemFragment): void
  (e: 'goToParent', item: { id: string }): void
}>()

const user = await useCurrentUser()
const isDraft = computed(() => props.modelValue.contributedAt === null)
const isByCurrentUser = computed(
  () => user.value?.id && props.modelValue.contributor?.id === user.value.id
)
</script>

<template>
  <select v-model="selectedTopicId">
    <option :value="null" :selected="modelValue.topic?.id === selectedTopicId">
      Topic wählen
    </option>
    <option
      v-for="topic of allTopics"
      :key="topic.id"
      :value="topic.id"
      :selected="modelValue.topic?.id === selectedTopicId"
    >
      <template v-if="topic.title">{{ topic.title }}</template>
      <template v-else-if="topic.slug">Thema {{ topic.slug }}</template>
      <template v-else>Thema {{ topic.id }}</template>
    </option>
  </select>
  <button @click="save()">save</button>
  <button @click="saveAndSubmit()">submit</button>
</template>

<script setup lang="ts">
import {
  type RoomItemAsListItemFragment,
  useFetchTopicsQuery,
  useUpdateRoomItemMutation,
} from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const { data: dataOfTopics } = await useFetchTopicsQuery({})
const allTopics = computed(() => dataOfTopics.value?.topics?.nodes ?? [])

const selectedTopicId = ref<string | null>(null)

// Create a deep copy of the messageBody in modelValue so we can modify it.
syncRef(
  computed(() => props.modelValue.topic?.id ?? null),
  selectedTopicId,
  {
    direction: 'ltr',
    immediate: true,
  }
)

// Save updated messageBody to the modelValue.
const { executeMutation: updateMutation } = useUpdateRoomItemMutation()

async function save() {
  await updateMutation({
    patch: { topicId: toValue(selectedTopicId) },
    oldId: props.modelValue.id,
  })
}

async function saveAndSubmit() {
  await updateMutation({
    patch: {
      topicId: toValue(selectedTopicId),
      contributedAt: new Date().toISOString(),
    },
    oldId: props.modelValue.id,
  })
}
</script>

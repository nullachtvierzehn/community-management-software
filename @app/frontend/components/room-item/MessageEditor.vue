<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <tiptap-editor v-model:json="editableMessageBody" />
  <button @click="save()">save</button>
  <button @click="saveAndSubmit()">submit</button>
</template>

<script lang="ts" setup>
import {
  type RoomItemAsListItemFragment,
  useUpdateRoomItemMutation,
} from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

// Create a deep copy of the messageBody in modelValue so we can modify it.
const editableMessageBody = shallowRef<any>()
syncRef(
  computed(() => props.modelValue.messageBody),
  editableMessageBody,
  {
    direction: 'ltr',
    deep: true,
    immediate: true,
    transform: {
      ltr(left) {
        if (!left || typeof left !== 'object')
          return { type: 'doc', content: [] }
        else return left
      },
    },
  }
)

// Save updated messageBody to the modelValue.
const { executeMutation: updateMutation } = useUpdateRoomItemMutation()

async function save() {
  await updateMutation({
    patch: { messageBody: toValue(editableMessageBody) },
    oldId: props.modelValue.id,
  })
}

async function saveAndSubmit() {
  await updateMutation({
    patch: {
      messageBody: toValue(editableMessageBody),
      contributedAt: new Date().toISOString(),
    },
    oldId: props.modelValue.id,
  })
}
</script>

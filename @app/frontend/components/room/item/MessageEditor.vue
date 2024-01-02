<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div>
    <div class="flex justify-between mb-4">
      <user-name class="font-bold" :profile="currentUser" />
      <div class="italic">Entwurf</div>
    </div>
    <form class="form-grid">
      <div class="form-input form-input_long">
        <label class="form-input__label">Nachricht</label>
        <tiptap-editor
          v-model:json="editableMessageBody"
          class="form-input__field"
          name="body"
        />
      </div>
      <div class="form-input">
        <label class="form-input__label">Sichtbar für</label>
        <multiselect
          :options="[
            { label: 'Raum-Default', value: null },
            { label: 'Mitglieder', value: 'MEMBER' },
          ]"
        ></multiselect>
      </div>
    </form>
    <div class="btn-bar mt-4">
      <button class="btn bg-gray-300 text-gray-700" @click="save()">
        speichern
      </button>
      <button class="btn btn_primary" @click="saveAndSubmit()">
        abschicken
      </button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import Multiselect from '@vueform/multiselect'

import {
  type RoomItemAsListItemFragment,
  useUpdateRoomItemMutation,
} from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const currentUser = await useCurrentUser()

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

<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div>
    <div class="flex justify-between mb-4">
      <user-name class="font-bold" :profile="modelValue.contributor" />
      <div class="italic">Entwurf</div>
    </div>

    <!-- Input for Message -->
    <form @submit="onSubmit" @reset="handleReset">
      <tiptap-editor
        v-model:json="content"
        v-bind="contentAttrs"
        :actions="[
          'bold',
          'italic',
          'paragraph',
          'double-quotes-l',
          'list-ordered',
          'list-unordered',
          'arrow-go-back-line',
          'arrow-go-forward-line',
        ]"
        class="form-input__field"
        name="body"
      />

      <!-- Answered message -->
      <div
        v-if="modelValue.parent"
        class="bg-gray-300 p-2 rounded-md my-4 block"
      >
        Antwort auf die Nachricht von
        <user-name
          :profile="modelValue.parent?.contributor"
          tag="span"
        />&nbsp;<span v-if="modelValue.parent.contributedAt"
          >am {{ formatDate(modelValue.parent.contributedAt, 'DD.MM.YY') }} ({{
            formatDateFromNow(modelValue.parent.contributedAt)
          }})</span
        >
        <span v-else>(noch im Entwurf)</span>
      </div>

      <div class="form-grid">
        <div class="form-input">
          <label class="form-input__label">Sichtbar</label>
          <select v-model="isVisibleFor" v-bind="isVisibleForAttrs">
            <option :value="null">gemäß Raum-Einstellung</option>
            <option value="MEMBER">für Mitglieder</option>
            <option value="MODERATOR">für Moderator:innen</option>
            <option value="ADMIN">für Administrator:innen</option>
          </select>
        </div>
      </div>

      <!-- Actions -->
      <div class="btn-bar mt-4 justify-end">
        <button
          type="button"
          class="btn bg-gray-300 text-gray-700"
          @click="deleteItem()"
        >
          löschen
        </button>
        <button
          type="submit"
          class="btn bg-gray-300 text-gray-700"
          @click="action = 'draft'"
        >
          speichern
        </button>
        <button
          type="submit"
          class="btn btn_primary"
          @click="action = 'submit'"
        >
          abschicken
        </button>
      </div>
    </form>
  </div>
</template>

<script lang="ts" setup>
import type { JSONContent } from '@tiptap/core'
import { toTypedSchema } from '@vee-validate/zod'
import { cloneDeep } from 'lodash-es'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import {
  type RoomItemAsListItemFragment,
  type RoomItemPatch,
  useDeleteRoomItemMutation,
  useUpdateRoomItemMutation,
} from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const {
  defineField,
  meta,
  handleSubmit,
  handleReset,
  errors: fieldErrors,
} = useForm({
  validationSchema: toTypedSchema(
    z.object({
      isVisibleFor: z
        .enum(['BANNED', 'PROSPECT', 'MEMBER', 'PUBLIC', 'MODERATOR', 'ADMIN'])
        .or(z.null()),
      messageBody: z.object({
        type: z.string(),
        content: z.array(z.any()),
      }),
      parentId: z.null().or(z.string().uuid()),
      action: z.enum(['delete', 'draft', 'submit']).or(z.undefined()),
    })
  ),
  initialValues: {
    isVisibleFor: props.modelValue.isVisibleFor ?? null,
    parentId: props.modelValue.parentId ?? null,
    messageBody:
      cloneDeep(props.modelValue.messageBody) ??
      ({ type: 'doc', content: [] } as JSONContent),
  },
})

const [content, contentAttrs] = defineField('messageBody')
const [isVisibleFor, isVisibleForAttrs] = defineField('isVisibleFor')
const [action, _actionAttrs] = defineField('action')
const [parentId, parentIdAttrs] = defineField('parentId')

// Create a deep copy of the messageBody in modelValue so we can modify it.
const editableMessageBody = shallowRef<any>()

syncRef(
  computed(() => props.modelValue.messageBody),
  content,
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

syncRef(
  computed(() => props.modelValue.isVisibleFor),
  isVisibleFor,
  { direction: 'ltr' }
)

// Save updated messageBody to the modelValue.
const { executeMutation: updateMutation } = useUpdateRoomItemMutation()
const { executeMutation: deleteMutation } = useDeleteRoomItemMutation()

async function deleteItem() {
  if (window.confirm('Die Nachricht wirklich löschen?')) {
    await deleteMutation({ id: props.modelValue.id })
  }
}

const onSubmit = handleSubmit(async (values) => {
  const { action, ...patch } = values
  if (action === 'submit') {
    ;(patch as RoomItemPatch).contributedAt ??= new Date().toISOString()
  }
  await updateMutation({
    patch,
    oldId: props.modelValue.id,
  })
})

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

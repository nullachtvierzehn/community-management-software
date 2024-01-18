<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div>
    <div class="flex justify-between mb-4">
      <user-name class="font-bold" :profile="modelValue.contributor" />
      <div class="flex gap-2">
        <div v-if="modelValue.contributedAt" class="italic">
          {{ $dayjs(modelValue.contributedAt).fromNow() }}
        </div>
        <div v-else class="italic">Entwurf</div>
        <slot name="contextMenuButton"></slot>
      </div>
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

      <div
        v-if="
          room?.mySubscription &&
          orderOfRole(room.mySubscription.role) >= orderOfRole('MODERATOR')
        "
        class="form-grid"
      >
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

      <!-- Attachments -->
      <Teleport v-if="showSearchModal" to="body">
        <SearchModal
          v-model:show="showSearchModal"
          :entities="['TOPIC']"
          @click-match="addAttachment($event)"
        />
      </Teleport>

      <div v-if="attachments.length">
        <template v-for="attachment in attachments" :key="attachment.id">
          <div class="relative">
            <button
              class="bg-gray-700 text-white p-1 rounded-full absolute right-2 top-2"
              @click="deleteAttachmentById(attachment.id)"
            >
              <i class="ri-close-line"></i>
            </button>
            <div
              v-if="attachment.topic"
              class="bg-green-300 p-2 overflow-hidden rounded-md shadow-md max-h-32"
            >
              <NuxtLink
                :to="{
                  name: 'topic/show',
                  params: { slug: attachment.topic?.slug.split('/') },
                }"
              >
                <tiptap-viewer
                  v-if="attachment.topic.contentPreview"
                  class="room-item__content room-item__topic"
                  :content="attachment.topic.contentPreview"
                />
              </NuxtLink>
            </div>
          </div>
        </template>
      </div>

      <!-- Actions -->
      <div class="flex justify-between mt-4 items-stretch">
        <div class="flex items-center">
          <button
            v-if="
              room?.mySubscription &&
              orderOfRole(room.mySubscription.role) >= orderOfRole('MODERATOR')
            "
            class="bg-gray-300 text-black p-1 rounded-full shadow-md"
            @click="showSearchModal = true"
          >
            <i class="ri-attachment-line"></i>
          </button>
        </div>
        <div class="btn-bar justify-end">
          <button
            type="button"
            class="btn bg-gray-300 text-gray-700"
            @click="deleteItem()"
          >
            löschen
          </button>
          <button
            v-if="!modelValue.contributedAt"
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
            <span v-if="modelValue.contributedAt">ändern</span>
            <span v-else>abschicken</span>
          </button>
        </div>
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
  type RoomItemAttachmentInput,
  type RoomItemPatch,
  type TextsearchMatch,
  useCreateRoomItemAttachmentMutation,
  useDeleteRoomItemAttachmentMutation,
  useDeleteRoomItemMutation,
  useFetchRoomItemAttachmentsQuery,
  useUpdateRoomItemMutation,
} from '~/graphql'

const props = defineProps<{
  modelValue: RoomItemAsListItemFragment
}>()

const emit = defineEmits<{
  (e: 'saved'): void
}>()

const room = await useRoom()

// fetch attachments
const { executeMutation: createAttachmentMutation } =
  useCreateRoomItemAttachmentMutation()

const { executeMutation: deleteAttachmentMutation } =
  useDeleteRoomItemAttachmentMutation()

const showSearchModal = useState(() => false)

const { data: attachmentData, executeQuery: refetchAttachments } =
  await useFetchRoomItemAttachmentsQuery({
    variables: computed(() => ({
      condition: { roomItemId: props.modelValue.id },
      orderBy: ['CREATED_AT_ASC'],
    })),
  })

const attachments = computed(
  () => attachmentData.value?.roomItemAttachments?.nodes ?? []
)

async function addAttachment(match?: TextsearchMatch) {
  if (!match) throw new Error('undefined match')

  const input: RoomItemAttachmentInput = { roomItemId: props.modelValue.id }

  switch (match.type) {
    case 'TOPIC':
      input.topicId = match.id
      break
  }

  const { error } = await createAttachmentMutation({
    input,
  })

  if (error) throw error
  refetchAttachments({ requestPolicy: 'cache-and-network' })
  showSearchModal.value = false
}

async function deleteAttachmentById(id: string) {
  if (window.confirm('Wollen Sie den Anhang löschen?')) {
    const { error } = await deleteAttachmentMutation({ id })
    if (error) throw error
    refetchAttachments({ requestPolicy: 'cache-and-network' })
  }
}

// define form to update message
const { defineField, handleSubmit, handleReset } = useForm({
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
//const [parentId, parentIdAttrs] = defineField('parentId')

// Create a deep copy of the messageBody in modelValue so we can modify it.
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
    ;(patch as RoomItemPatch).contributedAt ??=
      props.modelValue.contributedAt ?? new Date().toISOString()
  }
  const { error } = await updateMutation({
    patch,
    oldId: props.modelValue.id,
  })
  if (error) throw error
  emit('saved')
})
</script>

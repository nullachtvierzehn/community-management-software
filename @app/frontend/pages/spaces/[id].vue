<template>
  <NuxtLayout ref="pageRef" name="page">
    <template #header><div class="absolute"></div></template>
    <template v-if="space" #default>
      <h1>Raum {{ space.name }}</h1>

      <!-- show members -->
      <details class="mb-4">
        <summary>{{ space.subscriptions.totalCount }} Mitglieder</summary>
        <ul>
          <li
            v-for="subscription in space.subscriptions.nodes"
            :key="subscription.id"
          >
            {{ subscription.subscriber?.username }}
          </li>
        </ul>
      </details>

      <!-- show items -->
      <section id="items">
        <div v-for="item in items" :key="item.id" class="bg-gray-200 p-2 mb-2">
          <div class="flex justify-between align-baseline">
            <UserName
              v-if="item.editor"
              :profile="item.editor"
              class="font-bold"
            />
            <div v-if="item.times?.currentApprovalSince" class="text-sm">
              {{ formatDateFromNow(item.times.currentApprovalSince) }}
            </div>
          </div>

          <!-- body of message revision -->
          <TiptapViewer
            v-if="item.messageRevision"
            :content="item.messageRevision.body"
          />
          <template v-else>
            <pre>Fehler: Art von Item {{ item.id }} unbekannt.</pre>
          </template>
        </div>
      </section>

      <!-- uploads -->
      <section id="uploads">
        <!-- drop indicator -->
        <div v-if="isOverDropZone" class="bg-red-600">
          <span v-if="draggedFiles">{{ draggedFiles.length }}</span> Datei(en)
          hochladen
        </div>

        <!-- running uploads -->
        <div v-for="f in uploadingFiles" :key="f.name">
          <div>Datei: {{ f.name }}</div>
          <TusUpload :file="f" @complete="handleUploadCompletion" />
        </div>
      </section>

      <!-- add message -->
      <section id="add-message" class="absolute bottom-8 left-0 right-0">
        <div class="mx-auto container p-4">
          <TiptapEditor v-model:json="bodyOfNewMessage" class="shadow-xl" />
          <div class="text-right">
            <button
              class="mt-4 shadow-xl p-2 bg-indigo-600 text-white rounded-md"
              @click="sendMessage()"
            >
              absenden
            </button>
          </div>
        </div>
      </section>
    </template>
  </NuxtLayout>
</template>

<script setup lang="ts">
import { type JSONContent } from '@tiptap/core'
import type { CombinedError } from '@urql/vue'
import { useDropZone, useStorage } from '@vueuse/core'
import type { Upload } from 'tus-js-client'

import {
  GetFileRevisionByRevisionIdDocument,
  type GetFileRevisionByRevisionIdQuery,
  type GetFileRevisionByRevisionIdQueryVariables,
  useCreateMessageRevisionMutation,
  useCreateSpaceItemMutation,
  useCreateSpaceSubmissionMutation,
  useCreateSpaceSubmissionReviewMutation,
  useDeleteFileRevisionMutation,
  useDeleteMessageRevisionMutation,
  useDeleteSpaceItemMutation,
  useDeleteSpaceSubmissionMutation,
  useGetSpaceQuery,
} from '~/graphql'

definePageMeta({
  name: 'space/by-id',
})

const route = useRoute()

const { data } = await useGetSpaceQuery({
  variables: computed(() => ({ id: toValue(route.params.id) as string })),
})

const space = computed(() => data.value?.space)
const items = computed(() => data.value?.space?.items.nodes ?? [])

// create new messages
const bodyOfNewMessage = useStorage<JSONContent>(
  'bodyOfNewMessageIn:' + toValue(route.params.id),
  {}
)

const pageRef = ref<HTMLElement>()
const app = useNuxtApp()

const draggedFiles = ref<File[] | null>(null)
const uploadingFiles = ref<File[]>([])
const { isOverDropZone } = useDropZone(pageRef, {
  onDrop: (files: File[] | null) => {
    console.log('select files for upload ', files)
    if (files) uploadingFiles.value = uploadingFiles.value.concat(files)
  },
  onEnter(files) {
    console.log('enter with ', files)
    draggedFiles.value = files
  },
  onLeave() {
    draggedFiles.value = null
  },
  // specify the types of data to be received.
  dataTypes: ['image/png', 'image/jpeg', 'image/webp', 'application/pdf'],
})

const { executeMutation: createMessageRevision } =
  useCreateMessageRevisionMutation()
const { executeMutation: createSpaceItem } = useCreateSpaceItemMutation()
const { executeMutation: submitSpaceItem } = useCreateSpaceSubmissionMutation()
const { executeMutation: approveSpaceItem } =
  useCreateSpaceSubmissionReviewMutation()
const { executeMutation: deleteMessageRevision } =
  useDeleteMessageRevisionMutation()
const { executeMutation: deleteSpaceItem } = useDeleteSpaceItemMutation()
const { executeMutation: deleteSpaceSubmission } =
  useDeleteSpaceSubmissionMutation()
const { executeMutation: deleteFileRevision } = useDeleteFileRevisionMutation()

async function submitMessageOrFile(
  messageOrFile: {
    __typename?: 'MessageRevision' | 'FileRevision'
    id: string
    revisionId: string
  },
  revertSteps: Array<() => Promise<{ error?: CombinedError }>>
) {
  async function revert() {
    for (const step of revertSteps) {
      const { error } = await step()
      if (error) console.error('failed revert step', error)
    }
  }

  // Submissions depend on the current space.
  const currentSpace = toValue(space)
  if (!currentSpace) {
    throw new Error('Unknown current space.')
  }

  // create space item
  const { data: itemData, error: itemError } = await createSpaceItem({
    payload: {
      [messageOrFile.__typename === 'FileRevision' ? 'fileId' : 'messageId']:
        messageOrFile.id,
      revisionId: messageOrFile.revisionId,
      spaceId: currentSpace.id,
    },
  })
  const item = itemData?.createSpaceItem?.spaceItem
  if (itemError || !item) await revert()
  if (itemError) throw itemError
  if (!item) throw new Error('failed to create item')
  revertSteps.push(() => deleteSpaceItem({ id: item.id }))

  // create space submission
  const { data: submissionData, error: submissionError } =
    await submitSpaceItem({
      payload: {
        spaceItemId: item.id,
        messageId: item.messageId,
        fileId: item.fileId,
        revisionId: item.revisionId,
      },
    })
  const submission = submissionData?.createSpaceSubmission?.spaceSubmission
  if (submissionError || !submission) await revert()
  if (submissionError) throw submissionError
  if (!submission) throw new Error('failed to create submission')
  revertSteps.push(() => deleteSpaceSubmission({ id: submission.id }))

  // approve submission
  const { data: reviewData, error: reviewError } = await approveSpaceItem({
    payload: {
      spaceSubmissionId: submission.id,
      result: 'APPROVED',
    },
  })
  const review = reviewData?.createSpaceSubmissionReview?.spaceSubmissionReview
  if (reviewError || !review) await revert()
  if (reviewError) throw reviewError
  if (!review) throw new Error('failed to create review')
}

async function handleUploadCompletion(upload: Upload) {
  // Extract revision id from URL of the uploaded file.
  const match = upload.url?.match(/.*\/([a-fA-F0-9-]+)$/)
  if (!match) throw new Error(`Invalid url of uploaded file: ${upload.url}`)

  // Fetch the uploaded file
  const revisionId = match[1]
  const { data, error } = await app.$urql.query<
    GetFileRevisionByRevisionIdQuery,
    GetFileRevisionByRevisionIdQueryVariables
  >(
    GetFileRevisionByRevisionIdDocument,
    { revisionId },
    { requestPolicy: 'cache-and-network' }
  )
  if (error) throw error
  if (!data?.fileRevisionByRevisionId)
    throw new Error(
      `Unable to fetch file revision by revision id: ${revisionId}`
    )
  const fileRevision = data.fileRevisionByRevisionId
  await submitMessageOrFile(fileRevision, [
    () =>
      deleteFileRevision({
        id: fileRevision.id,
        revisionId: fileRevision.revisionId,
      }),
  ])
}

async function sendMessage() {
  // create message revision
  const { data: messageData, error: messageError } =
    await createMessageRevision({
      payload: { body: toValue(bodyOfNewMessage) },
    })
  const message = messageData?.createMessageRevision?.messageRevision
  if (messageError) throw messageError
  if (!message) throw new Error('failed to create message')

  // prepare to revert message creation and other upcoming steps.
  await submitMessageOrFile(message, [
    () =>
      deleteMessageRevision({
        id: message.id,
        revisionId: message.revisionId,
      }),
  ])
}
</script>

<style lang="postcss" scoped>
#items {
  & :deep(.tiptap-contents p:first-child) {
    @apply mt-1;
  }
  & :deep(.tiptap-contents p:last-child) {
    @apply mb-1;
  }
}

#add-message {
  & :deep(.tiptap-editor__menu-bar) {
    @apply m-1.5;
  }
  & :deep(.tiptap-editor__content) {
    @apply m-1.5 overflow-y-scroll max-h-[280px];
    & *:first-child {
      @apply mt-0;
    }
    & *:last-child {
      @apply mb-0;
    }
  }
  & :deep(.tiptap-editor__menu-item) {
    @apply text-gray-700;
  }
  & :deep(.tiptap-editor__menu-item.is-active) {
    @apply bg-gray-700 text-white;
  }
}
</style>

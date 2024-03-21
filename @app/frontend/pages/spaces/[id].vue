<template>
  <div
    ref="pageRef"
    name="page"
    class="container mx-auto p-4"
    :style="{
      marginBottom:
        hasAbility('CREATE') || hasAbility('MANAGE')
          ? windowSize.height -
            floatingEditorBounding.bottom +
            floatingEditorBounding.height +
            'px'
          : 'none',
    }"
  >
    <template v-if="!space">
      Der Space wurde nicht gefunden. {{ querySpaceError }}
    </template>
    <template v-else>
      <h1 class="text-4xl font-bold mb-4">Raum {{ space.name }}</h1>

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
            <div v-if="item.editor">
              {{ item.editor.username }}
            </div>
            <div v-else>[[ gelöscht ]]</div>
            <!--

              <UserName
              v-if="item.editor"
              :profile="item.editor"
              class="font-bold"
              />
            -->
            <div v-if="item.times?.currentApprovalSince" class="text-sm">
              {{ formatDateFromNow(item.times.currentApprovalSince) }}
            </div>
          </div>

          <!-- body of message revision -->
          <TiptapViewer
            v-if="item.messageRevision"
            :content="item.messageRevision.body"
          />
          <template
            v-else-if="item.fileRevision?.mimeType?.startsWith('image/')"
          >
            <img :src="`/backend/files/${item.fileRevision.revisionId}`" />
          </template>
          <template
            v-else-if="item.fileRevision?.mimeType?.startsWith('audio/')"
          >
            <audio
              :src="`/backend/files/${item.fileRevision.revisionId}`"
              controls
            />
          </template>
          <template
            v-else-if="item.fileRevision?.mimeType?.startsWith('video/')"
          >
            <video
              :src="`/backend/files/${item.fileRevision.revisionId}`"
              controls
            />
          </template>
          <template v-else>
            <pre>Fehler: Art von Item {{ item.id }} unbekannt.</pre>
          </template>
          <div
            v-if="
              !item.isSubmitted &&
              (hasAbility('SUBMIT') || hasAbility('MANAGE'))
            "
            class="bg-gray-300 -mx-2 -mb-2 p-2 text-right"
          >
            <button class="p-2 bg-indigo-600 text-white rounded-md text-xs">
              einreichen
            </button>
          </div>
          <div
            v-else-if="
              !item.latestReviewResult &&
              (hasAbility('ACCEPT') || hasAbility('MANAGE'))
            "
            class="bg-gray-300 -mx-2 -mb-2 p-2 flex gap-1 justify-end"
          >
            <button class="p-2 bg-indigo-600 text-white rounded-md text-xs">
              ablehnen
            </button>
            <button class="p-2 bg-indigo-600 text-white rounded-md text-xs">
              kommentieren
            </button>
            <button class="p-2 bg-indigo-600 text-white rounded-md text-xs">
              veröffentlichen
            </button>
          </div>
        </div>
      </section>

      <!-- uploads -->
      <section id="uploads">
        <!-- drop indicator -->
        <div v-if="isOverDropZone" class="bg-red-600">Datei(en) hochladen</div>

        <!-- running uploads -->
        <TusUpload
          v-for="file in uploadingFiles"
          :key="fingerprintFile(file)"
          v-slot="{ cancel, progress }"
          :file="file"
          @complete="handleUploadCompletion"
          @cancel="handleUploadCancel"
        >
          <div class="bg-gray-200 p-2 mb-3 relative">
            <div
              class="flex justify-between items-center"
              :style="{ '--progress': (progress?.toFixed(0) ?? 0) + '%' }"
            >
              <div>{{ file.name }}</div>
              <div class="flex justify-between gap-2 items-center">
                <div v-if="progress">{{ progress.toFixed(0) }} %</div>
                <button
                  class="p-2 bg-indigo-600 text-white rounded-md"
                  @click="cancel()"
                >
                  abbrechen
                </button>
              </div>
            </div>
            <!-- progress bar -->
            <div class="absolute bottom-0 left-0 w-full h-1 bg-gray-400">
              <div
                v-if="progress"
                class="bg-indigo-600 h-full"
                :style="{ width: progress.toFixed(0) + '%' }"
              ></div>
            </div>
          </div>
        </TusUpload>
      </section>

      <!-- add message -->
      <section
        v-if="hasAbility('CREATE') || hasAbility('MANAGE')"
        id="add-message"
        class="fixed bottom-8 left-0 right-0"
      >
        <div ref="floatingEditorRef" class="mx-auto container p-4">
          <TiptapEditor
            v-model:json="bodyOfNewMessage"
            class="bg-white shadow-xl"
          />
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
  </div>
</template>

<script setup lang="ts">
import { type JSONContent } from '@tiptap/core'
import type { CombinedError } from '@urql/vue'
import { useDropZone, useStorage } from '@vueuse/core'
import type { Upload } from 'tus-js-client'

import {
  type Ability,
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
  layout: false,
  name: 'space/by-id',
})

const route = useRoute()
const pageRef = ref<HTMLElement>()
const floatingEditorRef = ref<HTMLElement>()

const windowSize = reactive(useWindowSize())
const floatingEditorBounding = reactive(useElementBounding(floatingEditorRef))

const { data, error: querySpaceError } = await useGetSpaceQuery({
  variables: computed(() => ({ id: toValue(route.params.id) as string })),
})

const space = computed(() => data.value?.space)
const items = computed(() => data.value?.space?.items.nodes ?? [])
const myAbilities = computed(
  () => data.value?.space?.mySubscription?.allAbilities ?? []
)

function hasAbility(ability: Ability) {
  return myAbilities.value.includes(ability)
}

// create new messages
const bodyOfNewMessage = useStorage<JSONContent>(
  'bodyOfNewMessageIn:' + toValue(route.params.id),
  {}
)

const app = useNuxtApp()

const uploadingFiles = ref<File[]>([])
const { isOverDropZone } = useDropZone(pageRef, {
  onDrop: (files: File[] | null) => {
    console.log('select files for upload ', files)
    if (files) uploadingFiles.value = uploadingFiles.value.concat(files)
  },
  // specify the types of data to be received.
  dataTypes: [
    // images
    'image/png',
    'image/jpeg',
    'image/webp',
    // documents
    'application/pdf',
    // audio
    'audio/mpeg',
    'audio/mp4',
    'audio/ogg',
    'audio/aac',
    'audio/opus',
    'audio/webm',
    // video
    'video/mp4',
    'video/mpeg',
    'video/ogg',
    'video/webm',
  ],
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

function fingerprintFile(file: File) {
  return [file.name, file.type, file.size, file.lastModified].join('-')
}

async function submitMessageOrFile(
  messageOrFile: {
    __typename?: 'MessageRevision' | 'FileRevision'
    id: string
    revisionId: string
  },
  revertSteps: Array<() => Promise<{ error?: CombinedError }>>
) {
  async function revert() {
    for (const step of [...revertSteps].reverse()) {
      const { error } = await step()
      if (error) console.error('failed revert step', error)
    }
  }

  try {
    // Submissions depend on the current space.
    const currentSpace = toValue(space)
    if (!currentSpace) throw new Error('Unknown current space.')

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
    if (itemError) throw itemError
    if (!item) throw new Error('failed to create item')
    revertSteps.push(() => deleteSpaceItem({ id: item.id }))

    // create space submission
    if (!hasAbility('SUBMIT') && !hasAbility('MANAGE')) return

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
    if (submissionError) throw submissionError
    if (!submission) throw new Error('failed to create submission')
    revertSteps.push(() => deleteSpaceSubmission({ id: submission.id }))

    // approve submission
    if (!hasAbility('ACCEPT') && !hasAbility('MANAGE')) return

    const { data: reviewData, error: reviewError } = await approveSpaceItem({
      payload: {
        spaceSubmissionId: submission.id,
        result: 'APPROVED',
      },
    })
    const review =
      reviewData?.createSpaceSubmissionReview?.spaceSubmissionReview
    if (reviewError) throw reviewError
    if (!review) throw new Error('failed to create review')
  } catch (e) {
    await revert()
    throw e
  }
}

async function handleUploadCancel({ file }: Upload) {
  // Remove files from running uploads when completed.
  const index = uploadingFiles.value.findIndex((e) => e === file)
  if (index >= 0) uploadingFiles.value.splice(index, 1)
}

async function handleUploadCompletion({ url, file }: Upload) {
  // Extract revision id from URL of the uploaded file.
  const match = url?.match(/.*\/([a-fA-F0-9-]+)$/)
  if (!match) throw new Error(`Invalid url of uploaded file: ${url}`)

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

  // Remove files from running uploads when completed.
  const index = uploadingFiles.value.findIndex((e) => e === file)
  if (index >= 0) uploadingFiles.value.splice(index, 1)
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

  bodyOfNewMessage.value = { type: 'doc', content: [] }
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

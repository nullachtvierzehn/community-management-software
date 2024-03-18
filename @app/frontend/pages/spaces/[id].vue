<template>
  <NuxtLayout name="page">
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
import { useStorage } from '@vueuse/core'

import {
  useCreateMessageRevisionMutation,
  useCreateSpaceItemMutation,
  useCreateSpaceSubmissionMutation,
  useCreateSpaceSubmissionReviewMutation,
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

async function sendMessage() {
  const currentSpace = toValue(space)
  if (!currentSpace) {
    throw new Error('Unknown current space.')
  }

  // create message revision
  const { data: messageData, error: messageError } =
    await createMessageRevision({
      payload: { body: toValue(bodyOfNewMessage) },
    })
  const message = messageData?.createMessageRevision?.messageRevision
  if (messageError) throw messageError
  if (!message) throw new Error('failed to create message')

  // prepare to revert message creation and other upcoming steps.
  const revertSteps: Array<() => Promise<{ error?: CombinedError }>> = [
    () =>
      deleteMessageRevision({
        id: message.id,
        revisionId: message.revisionId,
      }),
  ]

  async function revert() {
    for (const step of revertSteps) {
      const { error } = await step()
      if (error) console.error('failed revert step', error)
    }
  }

  // create space item
  const { data: itemData, error: itemError } = await createSpaceItem({
    payload: {
      messageId: message.id,
      revisionId: message.revisionId,
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
        messageId: message.id,
        revisionId: message.revisionId,
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

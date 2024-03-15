<template>
  <article v-if="!space">Raum nicht gefunden.</article>
  <article v-else>
    <h1>Raum {{ space.name }}</h1>

    <!-- show members -->
    <details>
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
      <div v-for="item in items" :key="item.id">
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
    <TiptapEditor v-model:json="bodyOfNewMessage" />
    <button @click="sendMessage()">send new message</button>
  </article>
</template>

<script setup lang="ts">
import {
  useCreateMessageRevisionMutation,
  useCreateSpaceItemMutation,
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
const bodyOfNewMessage = ref({})
const { executeMutation: createMessageRevision } =
  useCreateMessageRevisionMutation()
const { executeMutation: createSpaceItem } = useCreateSpaceItemMutation()

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
  if (!message) throw new Error('failed to load message')

  // create space item
  const { error: itemError } = await createSpaceItem({
    payload: {
      messageId: message.id,
      revisionId: message.revisionId,
      spaceId: currentSpace.id,
    },
  })
  if (itemError) throw itemError
}
</script>

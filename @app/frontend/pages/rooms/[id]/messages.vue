<template>
  <section>
    <h1>Meine Entwürfe</h1>
    <!-- write message-->
    <room-message
      v-if="myDraftMessages.length === 0"
      :create-with-defaults="{ roomId: route.params.id as string }"
      @update:message="refetch()"
    />

    <!-- work on drafts -->
    <room-message
      v-for="message in myDraftMessages"
      :key="message.id"
      :message="message"
      editable
      edit
    />

    <!-- show messages -->
    <h1>Nachrichten</h1>
    <room-message
      v-for="message in messages"
      :key="message.id"
      :message="message"
    />
  </section>
</template>

<script lang="ts" setup>
import { useRouteQuery } from '@vueuse/router'

import { useFetchRoomMessagesQuery } from '~/graphql'

definePageMeta({
  name: 'room/messages',
  alias: ['/raeume/:id/nachrichten', '/r%C3%A4ume/:id/nachrichten'],
})

const route = useRoute()
const currentUser = useCurrentUser()
const nMessages = useRouteQuery<number>('n', 10, {
  transform: Number,
  mode: 'replace',
})

// fetch messages
const { data, executeQuery: fetchSentMessages } =
  await useFetchRoomMessagesQuery({
    variables: computed(() => ({
      condition: { roomId: route.params.id as string },
      filter: { sentAt: { isNull: false } },
      orderBy: ['CREATED_AT_DESC'],
      first: toValue(nMessages),
    })),
  })

const messages = computed(() => data.value?.roomMessages?.nodes ?? [])

// fetch my draft messages
const { data: dataOfMyDraftMessages, executeQuery: fetchDrafts } =
  await useFetchRoomMessagesQuery({
    pause: logicNot(currentUser),
    variables: computed(() => ({
      condition: {
        roomId: route.params.id as string,
        senderId: currentUser.value?.id,
      },
      filter: { sentAt: { isNull: true } },
      orderBy: ['CREATED_AT_DESC'],
      first: toValue(nMessages),
    })),
  })

const myDraftMessages = computed(
  () => dataOfMyDraftMessages.value?.roomMessages?.nodes ?? []
)

async function refetch() {
  return Promise.allSettled([fetchSentMessages(), fetchDrafts()])
}
</script>

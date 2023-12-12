<template>
  <section>
    <h1 class="sr-only">Entwürfe</h1>
    <!-- my draft items-->
    <client-only>
      <Teleport to="#roomHeaderButtons">
        <button @click="addNewMessage()">neue Nachricht</button>
        <button @click="addNewTopic()">neues Thema</button>
      </Teleport>
      <template #fallback>
        <noscript>Some buttons here for nonscript clients.</noscript>
      </template>
    </client-only>

    <div
      v-for="item in myDraftItems"
      :key="item.id"
      class="room-item room-item_is-draft"
    >
      <RoomItemMessageEditor
        v-if="item.type === 'MESSAGE'"
        :model-value="item"
      />
      <RoomItemTopicEditor
        v-else-if="item.type === 'TOPIC'"
        :model-value="item"
      />
      <pre v-else>{{ item }}</pre>
    </div>
  </section>

  <!-- submitted items -->
  <section class="grid gap-3">
    <h1 class="sr-only">Inhalte</h1>
    <div
      v-for="item in submittedItems"
      :key="item.id"
      class="block bg-gray-100 p-3 rounded-lg"
    >
      <RoomItemMessageViewer
        v-if="item.type === 'MESSAGE'"
        :model-value="item"
      />
      <RoomItemTopicViewer
        v-else-if="item.type === 'TOPIC'"
        :model-value="item"
      />
      <pre v-else>{{ item }}</pre>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { generateJSON } from '@tiptap/html'
import StarterKit from '@tiptap/starter-kit'
import { useRouteQuery } from '@vueuse/router'

import { useCreateRoomItemMutation, useFetchRoomItemsQuery } from '~/graphql'

definePageMeta({
  name: 'room/items',
  alias: ['/raeume/:id/items', '/r%C3%A4ume/:id/inhalte'],
})

const route = useRoute()
const currentUser = useCurrentUser()
const nItems = useRouteQuery<number>('n', 100, {
  transform: Number,
  mode: 'replace',
})

// fetch items
const { data: dataOfSubmittedItems, executeQuery: refetchItems } =
  await useFetchRoomItemsQuery({
    variables: computed(() => ({
      condition: { roomId: route.params.id as string },
      filter: { contributedAt: { isNull: false } },
      orderBy: ['ORDER_ASC', 'CONTRIBUTED_AT_ASC'],
      first: toValue(nItems),
    })),
  })

const submittedItems = computed(
  () => dataOfSubmittedItems.value?.roomItems?.nodes ?? []
)

// fetch my draft items
const { data: dataOfMyDraftItems, executeQuery: refetchDrafts } =
  await useFetchRoomItemsQuery({
    pause: logicNot(currentUser),
    variables: computed(() => ({
      condition: {
        roomId: route.params.id as string,
        contributorId: currentUser.value?.id,
      },
      filter: { contributedAt: { isNull: true } },
      orderBy: ['CREATED_AT_ASC'],
      first: toValue(nItems),
    })),
  })

const myDraftItems = computed(
  () => dataOfMyDraftItems.value?.roomItems?.nodes ?? []
)

async function refetch() {
  return Promise.allSettled([refetchItems(), refetchDrafts()])
}

// add new items
const { executeMutation: addMutation } = useCreateRoomItemMutation()

async function addNewMessage() {
  await addMutation({
    item: {
      roomId: route.params.id as string,
      type: 'MESSAGE',
      contributorId: currentUser.value?.id,
      messageBody: generateJSON('<p></p>', [StarterKit]),
    },
  })
  await refetchDrafts()
}

async function addNewTopic() {
  await addMutation({
    item: {
      roomId: route.params.id as string,
      type: 'TOPIC',
      contributorId: currentUser.value?.id,
    },
  })
  await refetchDrafts()
}
</script>

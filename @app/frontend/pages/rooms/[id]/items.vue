<template>
  <button @click="addNewMessage()">neue Nachricht</button>
  <button @click="showSearchModal = true">neues Thema</button>

  <Teleport v-if="showSearchModal" to="body">
    <SearchModal v-model:show="showSearchModal" :entities="['TOPIC']" />
  </Teleport>

  <!-- my draft items-->
  <section class="container mx-auto grid gap-3 mb-3">
    <h1 class="sr-only">Entwürfe</h1>

    <div
      v-for="item in myDraftItems"
      :key="item.id"
      class="border-2 border-gray-300 p-4 rounded-lg w-[80%]"
      :class="{ 'justify-self-end': isByCurrentUser }"
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
  <section class="container mx-auto grid gap-3">
    <h1 class="sr-only">Inhalte</h1>
    <div
      v-for="item in submittedItems"
      :key="item.id"
      class="border-2 border-gray-300 p-4 rounded-lg w-[80%]"
      :class="{ 'justify-self-end': isByCurrentUser }"
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
import type { UnwrapRef } from 'vue'

import { useCreateRoomItemMutation, useFetchRoomItemsQuery } from '~/graphql'

definePageMeta({
  name: 'room/items',
  alias: ['/raeume/:id/items', '/r%C3%A4ume/:id/inhalte'],
})

const route = useRoute()
const showSearchModal = useState(() => false)
const roomId = ref(route.params.id as string)
const currentUser = await useCurrentUser()
const nItems = useRouteQuery<number>('n', 100, {
  transform: Number,
  mode: 'replace',
})

// fetch items
const { data: dataOfSubmittedItems, executeQuery: refetchItems } =
  await useFetchRoomItemsQuery({
    variables: computed(() => ({
      condition: { roomId: toValue(roomId) },
      filter: { contributedAt: { isNull: false } },
      orderBy: ['CONTRIBUTED_AT_DESC'],
      first: toValue(nItems),
    })),
    pause: logicNot(roomId),
  })

const submittedItems = computed(
  () => dataOfSubmittedItems.value?.roomItems?.nodes ?? []
)

function isByCurrentUser(item: UnwrapRef<typeof submittedItems>[0]) {
  const user = toValue(currentUser)
  if (!user) return null
  else if (item.contributor?.id === user.id) return true
  else return false
}

// fetch my draft items
const { data: dataOfMyDraftItems, executeQuery: refetchDrafts } =
  await useFetchRoomItemsQuery({
    pause: computed(() => !currentUser.value || !roomId.value),
    variables: computed(() => ({
      condition: {
        roomId: toValue(roomId),
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

<style lang="postcss" scoped>
:deep(.tiptap-editor) {
  @apply border-gray-300 min-h-32;
}

:deep(.tiptap-editor__menu-bar) {
  @apply bg-gray-300;
}

:deep(.tiptap-editor__menu-item) {
  color: black;
}
</style>

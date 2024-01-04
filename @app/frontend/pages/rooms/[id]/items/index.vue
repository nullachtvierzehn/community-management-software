<template>
  <div class="container mx-auto flex justify-end">
    <button
      v-if="subscription"
      class="btn btn_primary my-4"
      @click="addNewMessage()"
    >
      neue Nachricht
    </button>
  </div>

  <Teleport v-if="showSearchModal" to="body">
    <SearchModal v-model:show="showSearchModal" :entities="['TOPIC']" />
  </Teleport>

  <!-- submitted items -->
  <section class="container mx-auto grid gap-3 mt-4">
    <h1 class="sr-only">Inhalte</h1>
    <template v-for="item in items" :key="item.id">
      <div
        :id="`item-${item.id}`"
        class="border-2 border-gray-300 p-4 rounded-lg w-[80%]"
        :class="{ 'justify-self-end': isByCurrentUser(item) }"
      >
        <RoomItemMessageEditor
          v-if="
            item.type === 'MESSAGE' && isDraft(item) && isByCurrentUser(item)
          "
          :model-value="item"
        />
        <RoomItemMessageViewer
          v-else-if="item.type === 'MESSAGE'"
          :model-value="item"
          @respond="addNewMessage(item)"
          @go-to-parent="goToParent($event)"
        />
        <RoomItemTopicEditor
          v-else-if="
            item.type === 'TOPIC' && isDraft(item) && isByCurrentUser(item)
          "
          :model-value="item"
        />
        <RoomItemTopicViewer
          v-else-if="item.type === 'TOPIC'"
          :model-value="item"
        />
        <pre v-else>{{ item }}</pre>
      </div>
      <div
        v-if="item.nthItemSinceLastVisit === '1' && subscription?.lastVisitAt"
        class="text-red-600 border-t border-red-600 text-center cursor-pointer"
        @click="visitToNow()"
      >
        Zuletzt warst Du
        {{ formatDateFromNow(subscription.lastVisitAt) }} hier. Zu den neuen
        Nachrichten.
      </div>
    </template>
  </section>
</template>

<script lang="ts" setup>
import { useRouteQuery } from '@vueuse/router'
import type { UnwrapRef } from 'vue'

import { useCreateRoomItemMutation, useFetchRoomItemsQuery } from '~/graphql'

definePageMeta({
  name: 'room/items',
  alias: ['/raeume/:id/items', '/r%C3%A4ume/:id/inhalte'],
})

const currentUser = await useCurrentUser()
const _room = await useRoom()
const { subscription, update: updateSubscription } =
  await useSubscriptionWithTools()

const route = useRoute()
const router = useRouter()
const showSearchModal = useState(() => false)
const roomId = ref(route.params.id as string)
const nItems = useRouteQuery<number>('n', 100, {
  transform: Number,
  mode: 'replace',
})

// fetch items
const { data: dataOfItems, executeQuery: refetch } =
  await useFetchRoomItemsQuery({
    variables: computed(() => ({
      condition: { roomId: toValue(roomId) },
      orderBy: ['CONTRIBUTED_AT_DESC'],
      first: toValue(nItems),
    })),
    pause: logicNot(roomId),
  })

const items = computed(() => dataOfItems.value?.roomItems?.nodes ?? [])

type Item = UnwrapRef<typeof items>[0]

function isByCurrentUser(item: Item) {
  const user = toValue(currentUser)
  if (!user) return null
  else if (item.contributor?.id === user.id) return true
  else return false
}

function isDraft(item: Item) {
  return item.contributedAt === null
}

async function visitToNow() {
  await updateSubscription({ lastVisitAt: new Date().toISOString() })
}

// add new items
const { executeMutation: addMutation } = useCreateRoomItemMutation()

async function addNewMessage(parent?: Item) {
  await addMutation({
    item: {
      roomId: route.params.id as string,
      type: 'MESSAGE',
      parentId: parent?.id ?? null,
      contributorId: currentUser.value?.id,
      messageBody: {
        type: 'doc',
        content: parent?.messageBody
          ? [{ type: 'blockquote', content: parent.messageBody.content }]
          : [],
      },
    },
  })
  await refetch()
}

async function goToParent(parent: { id: string }) {
  router.push({ hash: `#item-${parent.id}` })
}
</script>

<style lang="postcss" scoped>
:deep(.tiptap-editor) {
  @apply border-gray-300;
}

:deep(.tiptap-editor__menu-bar) {
  @apply bg-gray-300;
}

:deep(.tiptap-editor__menu-item) {
  color: black;
}

:deep(.tiptap-editor__menu-item:hover),
:deep(.tiptap-editor__menu-item.is-active) {
  color: white;
}

:deep(.tiptap-editor__content > .tiptap) {
  @apply min-h-16 max-h-48 overflow-y-auto;
}
</style>

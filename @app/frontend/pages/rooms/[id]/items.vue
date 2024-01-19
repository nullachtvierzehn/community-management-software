<template>
  <!-- Raum existiert nicht. -->
  <template v-if="!room">
    <p>Raum nicht gefunden.</p>
  </template>

  <!-- Room requires subscription. -->
  <template
    v-else-if="
      orderOfRole(room.itemsAreVisibleFor) >
      orderOfRole(mySubscription?.role ?? 'PUBLIC')
    "
  >
    <template v-if="mySubscription">
      <p>
        Inhalte sind nur sichtbar, wenn Sie mindestens die Rolle
        {{ room.itemsAreVisibleFor }} haben. Sie haben die Rolle
        {{ mySubscription.role }}.
      </p>
    </template>
    <template v-else>
      <div class="container mx-auto">
        <p>
          Sie müssen Mitglied im Raum sein, um die Nachrichten sehen zu können.
        </p>
        <button class="btn btn_primary" @click="subscribe()">
          Mitglied werden
        </button>
      </div>
    </template>
  </template>

  <!-- Items are accessible. -->
  <template v-else>
    <div v-if="mySubscription" class="container mx-auto flex justify-end mb-4">
      <button class="btn btn_primary" @click="addNewMessage()">
        neue Nachricht
      </button>
    </div>
    <div v-else class="bg-gray-200 -mx-4 -mt-4 mb-4">
      <div class="container mx-auto p-4 flex justify-between items-center">
        <div>
          Sie müssen Mitglied im Raum sein, um Nachrichten schreiben zu können.
        </div>
        <button class="btn btn_primary" @click="subscribe()">Eintreten</button>
      </div>
    </div>

    <Teleport v-if="showSearchModal" to="body">
      <SearchModal v-model:show="showSearchModal" :entities="['TOPIC']" />
    </Teleport>

    <!-- submitted items -->
    <section class="container mx-auto grid gap-3 mt-4">
      <h1 class="sr-only">Inhalte</h1>
      <template v-for="item in items" :key="item.id">
        <div
          class="border-2 border-gray-300 p-4 rounded-lg w-[80%]"
          :class="{ 'justify-self-end': isByCurrentUser(item) }"
        >
          <RoomItemMessage
            v-if="item.type === 'MESSAGE'"
            :model-value="item"
            @respond="addNewMessage(item)"
            @go-to-parent="goToParent($event)"
          >
            <template
              #floatingMenu="{
                isByCurrentUser: isByMe,
                showEditor,
                toggleEdit,
                toggleFloatingMenu,
              }"
            >
              <div class="context-menu" @click="toggleFloatingMenu()">
                <button
                  v-if="!isByMe"
                  class="context-menu__item"
                  @click="addNewMessage(item)"
                >
                  <i class="ri-question-answer-line"></i> antworten
                </button>
                <button
                  v-if="canEdit(item) && !showEditor"
                  class="context-menu__item"
                  @click="toggleEdit()"
                >
                  <i class="ri-edit-line"></i> bearbeiten
                </button>
                <button v-if="canDelete(item)" class="context-menu__item">
                  <i class="ri-chat-delete-line"></i> löschen
                </button>
              </div>
            </template>
          </RoomItemMessage>
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
          v-if="
            item.nthItemSinceLastVisit === '1' && mySubscription?.lastVisitAt
          "
          class="text-red-600 border-t border-red-600 text-center cursor-pointer"
          @click="visitToNow()"
        >
          Zuletzt warst Du
          {{ formatDateFromNow(mySubscription.lastVisitAt) }} hier. Zu den neuen
          Nachrichten.
        </div>
      </template>
    </section>
  </template>
</template>

<script lang="ts" setup>
import { useRouteQuery } from '@vueuse/router'

import { useCreateRoomItemMutation } from '~/graphql'

definePageMeta({
  name: 'room/items',
  alias: ['/raeume/:id/items', '/r%C3%A4ume/:id/inhalte'],
})

const currentUser = await useCurrentUser()
const {
  room,
  mySubscription,
  updateMySubscription,
  subscribe,
  hasRole,
  fetchItems,
  addItem,
} = await useRoomWithTools()

const route = useRoute()
const router = useRouter()
const showSearchModal = useState(() => false)
const nItems = useRouteQuery<number>('n', 100, {
  transform: Number,
  mode: 'replace',
})

const { items, refetch } = fetchItems({
  variables: computed(() => ({
    orderBy: ['CONTRIBUTED_AT_DESC'],
    first: toValue(nItems),
  })),
  requestPolicy: 'cache-and-network',
})

useIntervalFn(
  () => refetch({ requestPolicy: 'cache-and-network' }),
  30 * 1000, // ms
  { immediate: false }
)

function isByCurrentUser(item: RoomItemFromFetchQuery) {
  const user = toValue(currentUser)
  if (!user) return null
  else if (item.contributor?.id === user.id) return true
  else return false
}

function isDraft(item: RoomItemFromFetchQuery) {
  return item.contributedAt === null
}

function canEdit(item: RoomItemFromFetchQuery) {
  return isByCurrentUser(item) || hasRole('ADMIN', { orHigher: true })
}

function canDelete(item: RoomItemFromFetchQuery) {
  return isByCurrentUser(item) || hasRole('ADMIN', { orHigher: true })
}

async function visitToNow() {
  await updateMySubscription({ lastVisitAt: new Date().toISOString() })
}

// set lastVisitAt, if null
whenever(
  () => mySubscription.value && !mySubscription.value.lastVisitAt,
  () => updateMySubscription({ lastVisitAt: new Date().toISOString() }),
  { immediate: true }
)

// add new items
async function addNewMessage(parent?: RoomItemFromFetchQuery) {
  await addItem({
    roomId: route.params.id as string,
    type: 'MESSAGE',
    parentId: parent?.id ?? null,
    contributorId: currentUser.value?.id,
    messageBody: {
      type: 'doc',
      content: parent?.messageBody
        ? [
            { type: 'paragraph' },
            { type: 'blockquote', content: parent.messageBody.content },
          ]
        : [],
    },
  })
  await refetch()
}

async function goToParent(parent: { id: string }) {
  router.push({ hash: `#item-${parent.id}` })
}
</script>

<style lang="postcss" scoped>
.context-menu {
  @apply bg-gray-200 shadow-md rounded-lg overflow-hidden grid justify-items-stretch;
}

.context-menu__item {
  @apply p-2 hover:bg-gray-700 hover:text-white text-left;
}

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

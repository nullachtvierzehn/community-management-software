<template>
  <div
    v-if="show"
    class="modal__backdrop fixed top-0 left-0 w-full h-full backdrop-blur-lg grid justify-center items-center"
    @click.self="emit('update:show', false)"
  >
    <div
      class="modal min-w-[50vw] min-h-[50vh] bg-gray-400 text-white rounded-lg shadow-lg"
    >
      <div class="modal__search-input p-4 border-b border-b-gray-200">
        <input
          ref="searchField"
          v-model="term"
          type="search"
          class="text-black w-full rounded-sm text-2xl shadow-sm mb-2 p-1"
          placeholder="Suche…"
          @keyup.esc="emit('update:show', false)"
        />
        <div v-if="isPaused">Die Suche läuft ab 3 Buchstaben.</div>
        <div v-if="!isPaused && typeof totalCount === 'number'">
          {{ totalCount }} Treffer.
        </div>
      </div>
      <div v-if="error">
        <p>Die Suche lieferte einen Fehler:</p>
        <pre>{{ error }}</pre>
      </div>
      <div v-else-if="!isPaused && data" class="modal__matches p-4">
        <template v-for="match in matches" :key="match.id">
          <div
            class="modal__match rounded-md bg-gray-500 p-2 shadow-sm"
            @click="emit('clickMatch', match)"
          >
            <div class="text-xl font-semibold">{{ match.title }}</div>
            <div v-if="match.type == 'TOPIC'" class="italic">Thema</div>
            <div v-else-if="match.type == 'USER'" class="italic">User</div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {
  type GlobalSearchQuery,
  type TextsearchableEntity,
  useGlobalSearchQuery,
} from '~/graphql'

type Match = NonNullable<GlobalSearchQuery['globalSearch']>['nodes'][0]

const props = withDefaults(
  defineProps<{
    show: boolean
    entities: TextsearchableEntity[]
    skipIds: string[]
    focusOnShow: boolean
  }>(),
  {
    show: false,
    entities: () => ['TOPIC', 'USER'],
    skipIds: () => [],
    focusOnShow: false,
  }
)

const emit = defineEmits<{
  (e: 'update:show', show: boolean): void
  (e: 'clickMatch', match: Match): void
}>()

const term = useState(() => '')
const searchField = ref<HTMLInputElement>()

const { data, isPaused, error } = await useGlobalSearchQuery({
  variables: computed(() => ({
    term: toValue(term),
    entities: props.entities,
    filter: { id: { notIn: props.skipIds } },
  })),
  requestPolicy: 'cache-and-network',
  pause: computed(() => term.value.length < 3),
})

const totalCount = computed(() => data.value?.globalSearch?.totalCount)
const matches = computed(() => data.value?.globalSearch?.nodes ?? [])

onMounted(() => {
  if (props.focusOnShow) searchField.value?.focus()
})
</script>

<style lang="postcss" scoped></style>

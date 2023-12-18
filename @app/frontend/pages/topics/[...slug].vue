<template>
  <article v-if="fetching">Lädt...</article>
  <template v-else-if="!topic && edit === 'true'">
    <tiptap-editor v-model:json="editableJson" />
    <button @click="save()">speichern</button>
  </template>
  <article v-else-if="!topic && edit !== 'true'">
    Thema nicht gefunden. Möchtest Du es
    <button @click="edit = 'true'">anlegen?</button>
  </article>
  <article v-else-if="topic && edit !== 'true'">
    <h1>{{ topic.title ?? topic.slug }}</h1>
    <tiptap-viewer :content="topic.content" />
  </article>
  <article v-else-if="topic && edit === 'true'">
    <tiptap-editor v-model:json="editableJson" />
    <button @click="save()">speichern</button>
  </article>
</template>

<script lang="ts" setup>
import { type JSONContent } from '@tiptap/core'
import { useRouteQuery } from '@vueuse/router'

import {
  useCreateTopicMutation,
  useFetchDetailedTopicsQuery,
  useUpdateTopicMutation,
} from '~/graphql'

definePageMeta({
  name: 'topic/show',
})

const route = useRoute()
const edit = useRouteQuery('edit')
const slug = computed(() => {
  if (typeof route.params.slug === 'string') return route.params.slug
  else return route.params.slug.join('/')
})

const { data, fetching } = await useFetchDetailedTopicsQuery({
  variables: computed(() => ({
    filter: {
      organizationExists: false,
      slug: { equalTo: toValue(slug) },
    },
    first: 1,
  })),
})

/*
if (import.meta.server) {
  await useAsyncData(() =>
    Promise.all([{ then: fetchedTopic }]).then(([topicResponse]) => {
      if (topicResponse.error) throw topicResponse.error
    })
  )
}
*/

const topic = computed(() => data.value?.topics?.nodes[0])
const editableJson = shallowRef<JSONContent>({})
syncRef(
  computed(() => topic.value?.content),
  editableJson,
  {
    direction: 'ltr',
    deep: true,
    immediate: true,
    transform: {
      ltr(left) {
        if (!left || typeof left !== 'object')
          return { type: 'doc', content: [] }
        else return left
      },
    },
  }
)

const { executeMutation: createMutation } = useCreateTopicMutation()
const { executeMutation: updateMutation } = useUpdateTopicMutation()

async function save() {
  const oldId = topic.value?.id
  const { error } = await (oldId
    ? updateMutation({ oldId, patch: { content: toValue(editableJson) } })
    : createMutation({
        topic: {
          slug: toValue(slug),
          content: toValue(editableJson),
          organizationId: null,
        },
      }))
  if (error) throw error
}
</script>

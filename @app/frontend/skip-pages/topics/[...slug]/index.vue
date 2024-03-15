<template>
  <section v-if="topic" class="prose">
    <tiptap-viewer :content="topic.content" />
  </section>
</template>

<script lang="ts" setup>
import { useFetchDetailedTopicsQuery } from '~/graphql'

definePageMeta({
  layout: 'page',
  name: 'topic/show',
})

const route = useRoute()
const slug = computed(() => {
  if (typeof route.params.slug === 'string') return route.params.slug
  else return route.params.slug.join('/')
})

const { data } = await useFetchDetailedTopicsQuery({
  variables: computed(() => ({
    filter: {
      organizationExists: false,
      slug: { equalTo: toValue(slug) },
    },
    first: 1,
  })),
})

const topic = computed(() => data.value?.topics?.nodes[0])

useHeadSafe({
  title: topic.value?.title,
  meta: [{ name: 'keywords', content: topic.value?.tags.join(', ') }],
})
</script>

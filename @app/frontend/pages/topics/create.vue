<template>
  <h1>Neues Thema anlegen</h1>
  <form class="form-grid" @submit="onSubmit">
    <!-- title -->
    <div class="form-input">
      <label class="form-input__label">Titel</label>
      <input
        v-model="title"
        class="form-input__field"
        type="text"
        v-bind="titleAttrs"
      />
      <div v-if="fieldErrors.title" class="form-input__error">
        {{ fieldErrors.title }}
      </div>
    </div>

    <!-- slug -->
    <div class="form-input">
      <label class="form-input__label" for="createTopicInputSlug"
        >Titel in der Adresszeile</label
      >
      <div class="form-input__field">
        <input
          v-model="slug"
          class="block"
          type="text"
          v-bind="slugAttrs"
          @input="updateSlugFromTitle = false"
        />
        <label class="block"
          ><input v-model="updateSlugFromTitle" type="checkbox" /> automatisch
          aus Titel ableiten</label
        >
        <div v-if="fieldErrors.slug" class="form-input__error">
          {{ fieldErrors.slug }}
        </div>
      </div>
    </div>

    <!-- tags -->
    <div class="form-input">
      <label class="form-input__label" for="createTopicInputSlug"
        >Schlagworte</label
      >
      <Multiselect
        v-model="tags"
        class="form-input__field"
        mode="tags"
        :create-option="true"
        :searchable="true"
        :add-option-on="['enter', ',', ';']"
        :options="['Powerup', 'Challenge']"
        v-bind="tagsAttrs"
      />
    </div>

    <!-- content -->
    <div class="form-input sm:max-xl:form-input_long">
      <label class="form-input__label">Inhalt</label>
      <TiptapEditor
        v-model:json="content"
        name="content"
        class="form-input__field"
        v-bind="contentAttrs"
      />
    </div>

    <!-- submit -->
    <div class="form-input sm:max-xl:form-input_long">
      <button
        type="submit"
        class="form-input__field btn btn_primary"
        :disabled="!meta.valid"
      >
        anlegen
      </button>
    </div>
  </form>
</template>

<script setup lang="ts">
import { type JSONContent } from '@tiptap/core'
import { toTypedSchema } from '@vee-validate/zod'
import Multiselect from '@vueform/multiselect'
import { default as slugModule } from 'slug'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useCreateTopicMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
  middleware: ['auth'],
})

const router = useRouter()
const { executeMutation: createMutation } = useCreateTopicMutation()
const updateSlugFromTitle = useState(() => true)
const app = useNuxtApp()

const {
  defineField,
  meta,
  handleSubmit,
  errors: fieldErrors,
} = useForm({
  validationSchema: toTypedSchema(
    z.object({
      title: z.string().min(1, 'Gib bitte einen Titel ein'),
      slug: z.string().min(1, 'Gib bitte einen Titel für die Adresszeile ein.'),
      content: z.object({
        type: z.string(),
        content: z.array(z.any()),
      }),
      tags: z.array(z.string()),
    })
  ),
  initialValues: {
    title: '',
    slug: '',
    content: { type: 'doc', content: [] } as JSONContent,
    tags: [],
  },
})

const [title, titleAttrs] = defineField('title', {
  validateOnModelUpdate: false,
})
const [slug, slugAttrs] = defineField('slug', { validateOnModelUpdate: false })
const [content, contentAttrs] = defineField('content', {
  validateOnModelUpdate: false,
})
markRaw(content)
const [tags, tagsAttrs] = defineField('tags', { validateOnModelUpdate: false })

watch(
  [title, updateSlugFromTitle],
  ([newTitle, newUpdate], [oldTitle, oldUpdate]) => {
    if (
      (typeof newTitle === 'string' && newUpdate && !oldUpdate) ||
      (typeof newTitle === 'string' && newTitle !== oldTitle && newUpdate)
    )
      slug.value = slugModule(newTitle, { locale: app.$i18n.locale })
  }
)

const onSubmit = handleSubmit(async (values) => {
  if (process.browser) {
    const { data, error } = await createMutation({
      topic: values,
    })
    const topic = data?.createTopic?.topic
    if (topic && !error) {
      router.push({
        name: 'topic/show',
        params: { slug: topic.slug.split('/') },
        query: { edit: 'true' },
      })
    }
  }
})
</script>

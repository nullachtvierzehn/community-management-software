<template>
  <h1>Nachricht anlegen</h1>
  <form class="form-grid" @submit="onSubmit">
    <div class="form-input form-input_long">
      <tiptap-editor
        v-model:json="content"
        v-bind="contentAttrs"
        class="form-input__field"
        name="body"
      />
    </div>
    <div class="form-input">
      <label class="form-input__label">Sichtbar für</label>
      <multiselect
        v-model="isVisibleFor"
        mode="single"
        :options="[
          { label: 'Raum-Default', value: null },
          { label: 'Mitglieder', value: 'MEMBER' },
        ]"
        v-bind="isVisibleForAttrs"
      ></multiselect>
    </div>
    <div class="btn-bar mt-4">
      <button
        type="submit"
        name="submit"
        value="draft"
        class="btn bg-gray-300 text-gray-700"
        @click="action = 'draft'"
      >
        als Entwurf speichern
      </button>
      <button
        class="btn btn_primary"
        type="submit"
        value="submit"
        @click="action = 'submit'"
      >
        abschicken
      </button>
    </div>
  </form>
  <div>{{ meta }}</div>
</template>

<script setup lang="ts">
import type { JSONContent } from '@tiptap/core'
import { toTypedSchema } from '@vee-validate/zod'
import Multiselect from '@vueform/multiselect'
import { useForm } from 'vee-validate'
import { z } from 'zod'

definePageMeta({
  layout: 'page',
  renderAsTopLevelRoute: true,
})

const { defineField, meta, handleSubmit } = useForm({
  validationSchema: toTypedSchema(
    z.object({
      isVisibleFor: z.enum(['MEMBER', 'MODERATOR', 'ADMIN']).or(z.null()),
      content: z.object({
        type: z.string(),
        content: z.array(z.any()),
      }),
      action: z.enum(['draft', 'submit']).or(z.undefined()),
    })
  ),
  initialValues: {
    isVisibleFor: null,
    content: { type: 'doc', content: [] } as JSONContent,
  },
})

const onSubmit = handleSubmit(async (values) => {
  console.log(values)
})

const [content, contentAttrs] = defineField('content')
const [isVisibleFor, isVisibleForAttrs] = defineField('isVisibleFor')
const [action, _actionAttrs] = defineField('action')
</script>

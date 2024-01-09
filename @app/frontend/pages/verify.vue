<template>
  <template v-if="verificationSucceeded">
    <h1>E-Mail-Adresse bestätigt</h1>
    <p>
      Vielen Dank! Deine E-Mail-Adresse ist jetzt bestätigt. Möchtest Du Dich
      <NuxtLink to="/login">einloggen</NuxtLink>?
    </p>
  </template>
  <template v-else>
    <h1>E-Mail-Adresse bestätigen</h1>
    <form class="form-grid" @submit.prevent="onSubmit">
      <div class="form-input">
        <label for="emailVerificationId" class="form-input__label">
          Benutzer-Kennung
        </label>
        <input
          id="emailVerificationId"
          v-model.lazy="id"
          class="form-input__field"
          v-bind="idAttrs"
          type="text"
          aria-describedby="emailVerificationIdErrors"
        />
        <div
          v-show="fieldErrors.id"
          id="emailVerificationIdErrors"
          class="form-input__error"
        >
          {{ fieldErrors.id }}
        </div>
      </div>

      <label class="form-input">
        <label for="emailVerificationToken" class="form-input__label">
          Token as der E-Mail
        </label>
        <input
          id="emailVerificationToken"
          v-model.lazy="token"
          class="form-input__field"
          v-bind="tokenAttrs"
          type="text"
          aria-describedby="emailVerificationTokenErrors"
        />
        <div
          v-show="fieldErrors.token"
          id="emailVerificationTokenErrors"
          class="form-input__error"
        >
          {{ fieldErrors.token }}
        </div>
      </label>

      <div class="form-input">
        <button type="submit" class="form-input__field btn btn_primary">
          Abschicken
        </button>
        <div v-if="verificationError" class="form-input__error">
          <p>
            Leider gab es einen technischen Fehler. Versuche es bitte noch
            einmal und schreibe sonst an
            <a href="mailto:mail@a-friend.org">mail@a-friend.org</a>, damit
            wir Dir helfen können.
          </p>
        </div>
      </div>
    </form>
  </template>
</template>

<script setup lang="ts">
import { toTypedSchema } from '@vee-validate/zod'
import { useRouteQuery } from '@vueuse/router'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useVerifyEmailMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
})

const {
  executeMutation: verifyMutation,
  fetching: sending,
  error: verificationError,
} = useVerifyEmailMutation()

const verificationSucceeded = useState<boolean>(() => false)
const idFromUrl = useRouteQuery<string>('id', '')
const tokenFromUrl = useRouteQuery<string>('token', '')

const {
  defineField,
  handleSubmit,
  meta,
  submitForm,
  isSubmitting,
  errors: fieldErrors,
} = useForm({
  initialValues: { token: toValue(tokenFromUrl), id: toValue(idFromUrl) },
  validationSchema: toTypedSchema(
    z.object({
      id: z.string().uuid('Ungültige Kennung.'),
      token: z.string().min(14, 'Das Token muss 14 Zeichen enthalten.'),
    })
  ),
})

const [id, idAttrs] = defineField('id', { validateOnModelUpdate: false })
const [token, tokenAttrs] = defineField('token', {
  validateOnModelUpdate: false,
})

syncRef(idFromUrl, id as Ref<string>, { direction: 'both' })
syncRef(tokenFromUrl, token as Ref<string>, { direction: 'both' })

const onSubmit = handleSubmit(async ({ id, token }) => {
  const { data, error } = await verifyMutation({
    id,
    token,
  })
  verificationSucceeded.value = !error && (data?.verifyEmail?.success ?? false)
})

if (import.meta.browser) {
  whenever(
    () => meta.value.valid && !sending.value && !isSubmitting.value,
    submitForm
  )
} else if (meta.value.valid) {
  await onSubmit()
}
</script>

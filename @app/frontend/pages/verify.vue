<template>
  <article>
    <template v-if="verificationSucceeded">
      <h1>E-Mail-Adresse bestätigt</h1>
      <p>Vielen Dank! Ihre E-Mail-Adresse ist jetzt bestätigt.</p>
    </template>
    <template v-else>
      <h1>E-Mail-Adresse bestätigen</h1>
      <form @submit.prevent="onSubmit">
        <label for="emailVerificationId" class="block">
          <span>Kennung</span>
          <input
            id="emailVerificationId"
            v-model.lazy="id"
            v-bind="idAttrs"
            type="text"
            aria-describedby="emailVerificationIdErrors"
          />
          <div v-show="fieldErrors.id" id="emailVerificationIdErrors">
            {{ fieldErrors.id }}
          </div>
        </label>
        <label for="emailVerificationToken" class="block">
          <span>Token</span>
          <input
            id="emailVerificationToken"
            v-model.lazy="token"
            v-bind="tokenAttrs"
            type="text"
            aria-describedby="emailVerificationTokenErrors"
          />
          <div v-show="fieldErrors.token" id="emailVerificationTokenErrors">
            {{ fieldErrors.token }}
          </div>
        </label>
        <button type="submit">Abschicken</button>
        <pre>{{ fieldErrors }}</pre>
        <pre>{{ meta }}</pre>
      </form>
    </template>
  </article>
</template>

<script setup lang="ts">
import { toTypedSchema } from '@vee-validate/zod'
import { useRouteQuery } from '@vueuse/router'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useVerifyEmailMutation } from '~/graphql'

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

const { executeMutation: verifyMutation, fetching: sending } =
  useVerifyEmailMutation()

const onSubmit = handleSubmit(async ({ id, token }) => {
  const { data, error } = await verifyMutation({
    id,
    token,
  })
  verificationSucceeded.value = !error && (data?.verifyEmail?.ok ?? false)
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

<template>
  <h1>Passwort vergessen?</h1>
  <p>Wir schicken Dir eine E-Mail, damit Du Dir ein neues aussuchen kannst.</p>

  <form class="form-grid" @submit="onSubmit">
    <div class="form-input">
      <label for="resetPasswordInputEmail" class="form-input__label"
        >E-Mail-Adresse</label
      >
      <input
        id="resetPasswordInputEmail"
        v-model="email"
        class="form-input__field"
        type="email"
        v-bind="emailAttrs"
        aria-describedby="resetPasswordInputEmailErrors"
      />
      <div
        v-show="fieldErrors.email"
        id="resetPasswordInputEmailErrors"
        class="form-input__error"
      >
        {{ fieldErrors.email }}
      </div>
    </div>
    <div class="form-input">
      <button
        class="form-input__field btn btn_primary"
        type="submit"
        :disabled="!meta.valid || fetching"
      >
        ok
      </button>
      <div v-if="error" class="form-input__error">Es trat ein Fehler auf.</div>
    </div>
  </form>

  <p v-if="data">
    Wenn wir die Adresse kennen, schicken wir Dir in den nächsten Minuten eine
    E-Mail. Schau bitte nach. Falls in fünf Minuten nichts ankommt, schreibe
    bitte an <a href="mailto:hilfe@psychisch.fit">hilfe@psychisch.fit</a>, damit
    wir Dir helfen können.
  </p>
</template>

<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useForgotPasswordMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
})

const { executeMutation, data, error, fetching } = useForgotPasswordMutation()

const {
  defineField,
  meta,
  errors: fieldErrors,
  handleSubmit,
} = useForm({
  initialValues: {
    email: '',
  },
  validationSchema: toTypedSchema(
    z.object({
      email: z
        .string()
        .min(1, 'Fülle das E-Mail-Feld bitte aus.')
        .email(
          'Die E-Mail-Adresse ist ungültig. Prüfe sie bitte auf Tippfehler.'
        ),
    })
  ),
})

const [email, emailAttrs] = defineField('email', {
  validateOnModelUpdate: false,
})

const onSubmit = handleSubmit(async (values) => {
  await executeMutation(values)
})
</script>

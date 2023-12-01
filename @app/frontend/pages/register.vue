<template>
  <article>
    <h1>Als neu:e Benutzer:in anmelden</h1>
    <section>
      <form @submit.prevent="onSubmit">
        <label class="block">
          <span>Login-Name</span>
          <input v-model="username" type="text" v-bind="usernameAttrs" />
          <div v-if="fieldErrors.username">{{ fieldErrors.username }}</div>
        </label>
        <label class="block">
          <span>E-Mail</span>
          <input v-model="email" type="email" v-bind="emailAttrs" />
          <div v-if="fieldErrors.email">{{ fieldErrors.email }}</div>
        </label>
        <label class="block">
          <span>Passwort</span>
          <input v-model="password" type="password" v-bind="passwordAttrs" />
          <div v-if="fieldErrors.password">{{ fieldErrors.password }}</div>
        </label>
        <label class="block">
          <span>Passwort bestätigen</span>
          <input
            v-model="confirmPassword"
            type="password"
            v-bind="confirmPasswordAttrs"
          />
          <div v-if="fieldErrors.confirmPassword">
            {{ fieldErrors.confirmPassword }}
          </div>
        </label>
        <button
          class="block"
          :disabled="
            (!meta.touched && !meta.valid) || registrationInTransmission
          "
        >
          abschicken
        </button>
      </form>
    </section>
    <pre>{{ error }}</pre>
  </article>
</template>

<script setup lang="ts">
import { toTypedSchema } from '@vee-validate/zod'
import { omit } from 'lodash'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useRegisterUserMutation } from '~/graphql'

const schema = z
  .object({
    username: z
      .string()
      .min(3, 'Der Login-Name soll mindestens 3 Zeichen enthalten.')
      .regex(
        /^\p{L}+[\p{L}\p{N}]+$/u,
        'Der Login-Name darf nur aus Buchstaben und Zahlen bestehen, und er muss mit einem Buchstaben beginnen. Bitte keine Leerzeichen oder Sonderzeichen.'
      ),
    email: z
      .string()
      .min(1, 'Die E-Mail-Adresse ist nötig.')
      .email('Die E-Mail-Adresse ist ungültig.'),
    password: z
      .string()
      .min(8, 'Das Passwort soll mindestens acht Zeichen enthalten.'),
    confirmPassword: z
      .string()
      .min(
        1,
        'Das Passwort bitte wiederholen, damit es sicher richtig getippt ist.'
      ),
  })
  .superRefine(({ password, confirmPassword }, { addIssue, path }) => {
    if (password !== confirmPassword)
      addIssue({
        message: 'Das Passwort ist zwei Mal unterschiedlich eingetippt worden.',
        code: 'custom',
        path: [...path, 'confirmPassword'],
        fatal: true,
      })
  })

const {
  defineField,
  meta,
  errors: fieldErrors,
  handleSubmit,
} = useForm({
  validationSchema: toTypedSchema(schema),
  initialValues: {
    username: '',
    email: '',
    password: '',
    confirmPassword: '',
  },
})

const [email, emailAttrs] = defineField('email', {
  validateOnModelUpdate: false,
})
const [username, usernameAttrs] = defineField('username', {
  validateOnModelUpdate: false,
})
const [password, passwordAttrs] = defineField('password', {
  validateOnModelUpdate: false,
})
const [confirmPassword, confirmPasswordAttrs] = defineField('confirmPassword', {
  validateOnModelUpdate: false,
})

const {
  executeMutation,
  data: registrationResultData,
  error,
  fetching: registrationInTransmission,
} = useRegisterUserMutation()

const onSubmit = handleSubmit(async (data) => {
  executeMutation({
    form: omit(data, 'confirmPassword'),
  })
})
</script>

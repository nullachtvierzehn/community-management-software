<template>
  <article>
    <h1>Als neu:e Benutzer:in anmelden</h1>
    <section>
      <form @submit.prevent="onSubmit">
        <!-- username -->
        <label for="registrationInputUsername" class="block">
          <span>Login-Name</span>
          <input
            id="registrationInputUsername"
            v-model="username"
            type="text"
            v-bind="usernameAttrs"
            aria-describedby="registrationInputUsernameErrors"
          />
          <div
            v-show="fieldErrors.username"
            id="registrationInputUsernameErrors"
          >
            {{ fieldErrors.username }}
          </div>
        </label>

        <!-- email -->
        <label for="registrationInputEmail" class="block">
          <span>E-Mail</span>
          <input
            id="registrationInputEmail"
            v-model="email"
            type="email"
            v-bind="emailAttrs"
          />
          <div v-show="fieldErrors.email">{{ fieldErrors.email }}</div>
        </label>

        <!-- password -->
        <label for="registrationInputPassword" class="block">
          <span>Passwort</span>
          <input
            id="registrationInputPassword"
            v-model="password"
            type="password"
            v-bind="passwordAttrs"
            aria-describedby="registrationInputPasswordErrors"
          />
          <div
            v-show="fieldErrors.password"
            id="registrationInputPasswordErrors"
          >
            {{ fieldErrors.password }}
          </div>
        </label>

        <!-- password confirmation -->
        <label for="registrationInputConfirmPassword" class="block">
          <span>Passwort bestätigen</span>
          <input
            id="registrationInputConfirmPassword"
            v-model="confirmPassword"
            type="password"
            v-bind="confirmPasswordAttrs"
            aria-describedby="registrationInputConfirmPasswordErrors"
          />
          <div
            v-show="fieldErrors.confirmPassword"
            id="registrationInputConfirmPasswordErrors"
          >
            {{ fieldErrors.confirmPassword }}
          </div>
        </label>

        <!-- submit button -->
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
import type { Client } from '@urql/vue'
import { toTypedSchema } from '@vee-validate/zod'
import { omit } from 'lodash'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import {
  GetUserByUsername,
  type GetUserByUsernameQuery,
  useRegisterUserMutation,
} from '~/graphql'

const app = useNuxtApp()

const {
  executeMutation,
  data: registrationResultData,
  error,
  fetching: registrationInTransmission,
} = useRegisterUserMutation()

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
  .superRefine(
    async ({ password, confirmPassword, username }, { addIssue, path }) => {
      // check if password matches
      if (password !== confirmPassword)
        addIssue({
          message:
            'Das Passwort ist zwei Mal unterschiedlich eingetippt worden.',
          code: 'custom',
          path: [...path, 'confirmPassword'],
          fatal: true,
        })

      // check for users
      const { data } = await app.$urql.query<GetUserByUsernameQuery>(
        GetUserByUsername,
        { username }
      )

      if (data?.userByUsername?.id)
        addIssue({
          message: 'Der Login-Name ist bereits vergeben',
          code: 'custom',
          path: [...path, 'username'],
          fatal: true,
        })
    }
  )

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

const onSubmit = handleSubmit(async (data) => {
  executeMutation({
    form: omit(data, 'confirmPassword'),
  })
})
</script>

<template>
  <h1>Als neu:e Benutzer:in anmelden</h1>
  <section>
    <form class="form-grid" @submit.prevent="onSubmit">
      <!-- username -->
      <div class="form-input">
        <label for="registrationInputUsername" class="form-input__label"
          >Login-Name</label
        >
        <input
          id="registrationInputUsername"
          v-model="username"
          class="form-input__field"
          type="text"
          v-bind="usernameAttrs"
          aria-describedby="registrationInputUsernameErrors"
        />
        <div
          v-show="fieldErrors.username"
          id="registrationInputUsernameErrors"
          class="form-input__error"
        >
          {{ fieldErrors.username }}
        </div>
      </div>

      <!-- email -->
      <div class="form-input">
        <label for="registrationInputEmail" class="form-input__label"
          >E-Mail</label
        >
        <input
          id="registrationInputEmail"
          v-model="email"
          class="form-input__field"
          type="email"
          v-bind="emailAttrs"
          aria-describedby="registrationInputEmailErrors"
        />
        <div
          v-show="fieldErrors.email"
          id="registrationInputEmailErrors"
          class="form-input__error"
        >
          {{ fieldErrors.email }}
        </div>
      </div>

      <!-- password -->
      <div class="form-input">
        <label for="registrationInputPassword" class="form-input__label"
          >Passwort</label
        >
        <input
          id="registrationInputPassword"
          v-model="password"
          class="form-input__field"
          type="password"
          v-bind="passwordAttrs"
          aria-describedby="registrationInputPasswordErrors"
        />
        <div
          v-show="fieldErrors.password"
          id="registrationInputPasswordErrors"
          class="form-input__error"
        >
          {{ fieldErrors.password }}
        </div>
      </div>

      <!-- password confirmation -->
      <div class="form-input">
        <label for="registrationInputConfirmPassword" class="form-input__label"
          >Passwort bestätigen</label
        >
        <input
          id="registrationInputConfirmPassword"
          v-model="confirmPassword"
          class="form-input__field"
          type="password"
          v-bind="confirmPasswordAttrs"
          aria-describedby="registrationInputConfirmPasswordErrors"
        />
        <div
          v-show="fieldErrors.confirmPassword"
          id="registrationInputConfirmPasswordErrors"
          class="form-input__error"
        >
          {{ fieldErrors.confirmPassword }}
        </div>
      </div>

      <!-- submit button -->
      <button
        class="btn btn_primary"
        :disabled="(!meta.touched && !meta.valid) || registrationInTransmission"
      >
        abschicken
      </button>
    </form>
  </section>
  <pre>{{ error }}</pre>
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

definePageMeta({
  layout: 'page',
})

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

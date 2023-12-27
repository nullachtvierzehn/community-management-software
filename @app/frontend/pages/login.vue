<template>
  <h1>Einloggen</h1>

  <form action="post" class="form-grid" @submit="onSubmit">
    <div class="form-input">
      <label for="loginInputUsername" class="form-input__label"
        >Login-Name</label
      >
      <input
        id="loginInputUsername"
        v-model="username"
        v-bind="usernameAttrs"
        class="form-input__field"
        type="text"
        aria-describedby="loginInputUsernameErrors"
      />
      <div
        v-show="fieldErrors.username"
        id="loginInputUsernameErrors"
        class="form-input__error"
      >
        {{ fieldErrors.username }}
      </div>
    </div>

    <div class="form-input">
      <label for="loginInputPassword" class="form-input__label">Passwort</label>
      <input
        id="loginInputPassword"
        v-model="password"
        v-bind="passwordAttrs"
        class="form-input__field"
        type="password"
        aria-describedby="loginInputPasswordErrors"
      />
      <div
        v-show="fieldErrors.password"
        id="loginInputPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.password }}
      </div>
    </div>

    <button class="btn btn_primary" type="submit" :disabled="!meta.valid">
      ok
    </button>
  </form>

  <pre v-if="error">{{ error }}</pre>
  <pre v-if="data">{{ data }}</pre>
</template>

<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useLoginMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
})

const { data, executeMutation, error } = useLoginMutation()

const {
  defineField,
  meta,
  errors: fieldErrors,
  handleSubmit,
} = useForm({
  validationSchema: toTypedSchema(
    z.object({
      username: z.string().min(1, 'Gib bitte Deinen Login-Namen ein.'),
      password: z.string().min(1, 'Gib bitte Dein Passwort ein.'),
    })
  ),
  initialValues: {
    username: '',
    password: '',
  },
})

const [username, usernameAttrs] = defineField('username', {
  validateOnModelUpdate: false,
})
const [password, passwordAttrs] = defineField('password', {
  validateOnModelUpdate: false,
})

async function login() {
  await executeMutation({
    username: toValue(username)!,
    password: toValue(password)!,
  })
}

const onSubmit = handleSubmit(login)
</script>

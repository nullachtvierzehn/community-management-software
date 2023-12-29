<template>
  <h1>Passwort zurücksetzen</h1>

  <form class="form-grid" @submit="onSubmit">
    <!-- password -->
    <div class="form-input">
      <label for="resetPasswordInputPassword" class="form-input__label"
        >Passwort</label
      >
      <input
        id="resetPasswordInputPassword"
        v-model="password"
        class="form-input__field"
        type="password"
        v-bind="passwordAttrs"
        aria-describedby="resetPasswordInputPasswordErrors"
      />
      <div
        v-show="fieldErrors.password"
        id="resetPasswordInputPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.password }}
      </div>
    </div>

    <!-- password confirmation -->
    <div class="form-input">
      <label for="resetPasswordInputConfirmPassword" class="form-input__label"
        >Passwort nochmal eintippen</label
      >
      <input
        id="resetPasswordInputConfirmPassword"
        v-model="confirmPassword"
        class="form-input__field"
        type="password"
        v-bind="confirmPasswordAttrs"
        aria-describedby="resetPasswordInputConfirmPasswordErrors"
      />
      <div
        v-show="fieldErrors.confirmPassword"
        id="resetPasswordInputConfirmPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.confirmPassword }}
      </div>
    </div>

    <div class="form-input">
      <button
        type="submit"
        class="form-input__field btn btn_primary"
        :disabled="
          !meta.valid || fetching || data?.resetPassword?.success === true
        "
      >
        ok
      </button>
      <div
        v-if="error || data?.resetPassword?.success === false"
        class="form-input__error"
      >
        <p>Beim Zurücksetzen trat ein Fehler auf.</p>
        <pre>{{ error }}</pre>
      </div>
    </div>
  </form>

  <p v-if="data?.resetPassword?.success">
    Vielen Dank. Ab sofort gilt das neue Passwort. Magst Du Dich
    <NuxtLink to="/login">neu einloggen</NuxtLink>?
  </p>
</template>

<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod'
import { useRouteQuery } from '@vueuse/router'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useResetPasswordMutation } from '../graphql/index.js'

definePageMeta({
  layout: 'page',
})

const id = useRouteQuery('user_id')
const token = useRouteQuery('token')

const {
  executeMutation: resetMutation,
  fetching,
  data,
  error,
} = useResetPasswordMutation()

const {
  defineField,
  meta,
  errors: fieldErrors,
  handleSubmit,
} = useForm({
  validationSchema: toTypedSchema(
    z
      .object({
        password: z
          .string()
          .min(8, 'Das Passwort soll mindestens acht Zeichen lang sein.'),
        confirmPassword: z
          .string()
          .min(
            1,
            'Das Passwort bitte wiederholen, damit es sicher richtig getippt ist.'
          ),
      })
      .superRefine(
        async ({ password, confirmPassword }, { addIssue, path }) => {
          // check if password matches
          if (password !== confirmPassword)
            addIssue({
              message:
                'Das Passwort ist zwei Mal unterschiedlich eingetippt worden.',
              code: 'custom',
              path: [...path, 'confirmPassword'],
              fatal: true,
            })
        }
      )
  ),
  initialValues: {
    password: '',
    confirmPassword: '',
  },
})

const [password, passwordAttrs] = defineField('password', {
  validateOnModelUpdate: false,
})

const [confirmPassword, confirmPasswordAttrs] = defineField('confirmPassword', {
  validateOnModelUpdate: false,
})

const onSubmit = handleSubmit(async (values) => {
  await resetMutation({
    newPassword: values.password,
    token: toValue(token) as string,
    id: toValue(id) as string,
  })
})
</script>

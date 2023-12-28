<template>
  <h1>Passwort ändern</h1>

  <form class="form-grid" @submit="onSubmit">
    <!-- password -->
    <div class="form-input">
      <label for="changePasswordInputOldPassword" class="form-input__label"
        >Bisheriges Passwort</label
      >
      <input
        id="changePasswordInputOldPassword"
        v-model="oldPassword"
        class="form-input__field"
        type="password"
        v-bind="oldPasswordAttrs"
        aria-describedby="changePasswordInputOldPasswordErrors"
      />
      <div
        v-show="fieldErrors.oldPassword"
        id="changePasswordInputOldPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.oldPassword }}
      </div>
    </div>

    <!-- new password -->
    <div class="form-input">
      <label for="changePasswordInputNewPassword" class="form-input__label"
        >Das neue Passwort</label
      >
      <input
        id="changePasswordInputNewPassword"
        v-model="newPassword"
        class="form-input__field"
        type="password"
        v-bind="newPasswordAttrs"
        aria-describedby="changePasswordInputNewPasswordErrors"
      />
      <div
        v-show="fieldErrors.newPassword"
        id="changePasswordInputNewPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.newPassword }}
      </div>
    </div>

    <!-- password confirmation -->
    <div class="form-input">
      <label
        for="changePasswordInputConfirmNewPassword"
        class="form-input__label"
        >Das neue Passwort nochmal eintippen</label
      >
      <input
        id="changePasswordInputConfirmNewPassword"
        v-model="confirmNewPassword"
        class="form-input__field"
        type="password"
        v-bind="confirmNewPasswordAttrs"
        aria-describedby="changePasswordInputConfirmNewPasswordErrors"
      />
      <div
        v-show="fieldErrors.confirmNewPassword"
        id="changePasswordInputConfirmNewPasswordErrors"
        class="form-input__error"
      >
        {{ fieldErrors.confirmNewPassword }}
      </div>
    </div>

    <div class="form-input">
      <button
        type="submit"
        class="form-input__field btn btn_primary"
        :disabled="
          !meta.valid || fetching || data?.changePassword?.success === true
        "
      >
        ok
      </button>
      <div
        v-if="error || data?.changePassword?.success === false"
        class="form-input__error"
      >
        <p>Beim Zurücksetzen trat ein Fehler auf.</p>
        <pre>{{ error }}</pre>
      </div>
    </div>
  </form>

  <p v-if="data?.changePassword?.success">
    Das Passwort wurde erfolgreich geändert.
  </p>
</template>

<script setup lang="ts">
import { toTypedSchema } from '@vee-validate/zod'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useChangePasswordMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
  middleware: ['auth'],
})

const { executeMutation, data, error, fetching } = useChangePasswordMutation()

const {
  defineField,
  meta,
  errors: fieldErrors,
  handleSubmit,
} = useForm({
  validationSchema: toTypedSchema(
    z
      .object({
        oldPassword: z.string().min(1, 'Gib bitte das jetzige Passwort ein.'),
        newPassword: z
          .string()
          .min(8, 'Das neue Passwort soll mindestens acht Zeichen lang sein.'),
        confirmNewPassword: z
          .string()
          .min(
            1,
            'Das neue Passwort bitte wiederholen, damit es sicher richtig getippt ist.'
          ),
      })
      .superRefine(
        async ({ newPassword, confirmNewPassword }, { addIssue, path }) => {
          // check if password matches
          if (newPassword !== confirmNewPassword)
            addIssue({
              message:
                'Das Passwort ist zwei Mal unterschiedlich eingetippt worden.',
              code: 'custom',
              path: [...path, 'confirmNewPassword'],
              fatal: true,
            })
        }
      )
  ),
  initialValues: {
    oldPassword: '',
    newPassword: '',
    confirmNewPassword: '',
  },
})

const [oldPassword, oldPasswordAttrs] = defineField('oldPassword', {
  validateOnModelUpdate: false,
})
const [newPassword, newPasswordAttrs] = defineField('newPassword', {
  validateOnModelUpdate: false,
})
const [confirmNewPassword, confirmNewPasswordAttrs] = defineField(
  'confirmNewPassword',
  { validateOnModelUpdate: false }
)

const onSubmit = handleSubmit(async (values) => {
  await executeMutation({
    newPassword: values.newPassword,
    oldPassword: values.oldPassword,
  })
})
</script>

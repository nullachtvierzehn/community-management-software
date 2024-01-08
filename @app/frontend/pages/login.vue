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

    <div class="form-input">
      <button
        class="form-input__field btn btn_primary"
        type="submit"
        :disabled="!meta.valid"
      >
        ok
      </button>
      <div v-if="error" class="form-input__error">
        <p v-if="invalidCredentials">
          Login-Name und Passwort passen nicht zusammen. Magst Du
          <NuxtLink to="/reset-password">Dein Passwort zurücksetzen</NuxtLink>?
        </p>
        <div v-else>
          <p>Beim Einloggen kam es zu einem unbekannten Fehler:</p>
          <pre>{{ errorAsJson }}</pre>
          <pre>{{ data }}</pre>
        </div>
      </div>
    </div>
  </form>

  <div class="grid grid-cols-[1fr_2fr] gap-2 my-4">
    <p>Passwort vergessen?</p>
    <NuxtLink to="/forgot-password" class="btn btn_secondary"
      >Passwort zurücksetzen</NuxtLink
    >
    <p>Neu hier?</p>
    <NuxtLink to="/register" class="btn btn_secondary">Zur Anmeldung</NuxtLink>
  </div>

  <p v-if="data?.login?.user">
    Du hast Dich eingeloggt. Vielen Dank, dass Du wieder bei uns zu Besuch bist.
  </p>
</template>

<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod'
import { useRouteQuery } from '@vueuse/router'
import { useForm } from 'vee-validate'
import { z } from 'zod'

import { useLoginMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
})

const router = useRouter()
const next = useRouteQuery<string | null>('next')
const { data, executeMutation, error } = useLoginMutation()

const invalidCredentials = computed(
  () => error.value?.graphQLErrors.some((e) => e.extensions.code === 'CREDS')
)

const errorAsJson = computed(() => JSON.stringify(error))

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

const _r = useState(() => true)

const [username, usernameAttrs] = defineField('username', {
  validateOnModelUpdate: false,
})
const [password, passwordAttrs] = defineField('password', {
  validateOnModelUpdate: false,
})

async function login() {
  const { data, error } = await executeMutation({
    username: toValue(username)!,
    password: toValue(password)!,
  })
  if (!error && data?.login?.user) {
    router.push(next.value ?? '/profile')
  }
}

const onSubmit = handleSubmit(login)
</script>

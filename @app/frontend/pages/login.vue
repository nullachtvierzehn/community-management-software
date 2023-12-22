<template>
  <form action="post" class="form-grid max-w-[500px]" @submit.prevent="login()">
    <label for="loginInputUsername" class="form-input">
      <span class="form-input__label">Login-Name</span>
      <input
        id="loginInputUsername"
        v-model="username"
        class="form-input__field"
        type="text"
      />
    </label>
    <label for="loginInputPassword" class="form-input">
      <span class="form-input__label">Passwort</span>
      <input
        id="loginInputPassword"
        v-model="password"
        class="form-input__field"
        type="password"
      />
    </label>
    <button class="btn btn_primary" type="submit">ok</button>
  </form>
  <pre v-if="error">{{ error }}</pre>
  <pre v-if="data">{{ data }}</pre>
</template>

<script lang="ts" setup>
import { useLoginMutation } from '~/graphql'

const username = ref('')
const password = ref('')
const { data, executeMutation, error } = useLoginMutation()

async function login() {
  await executeMutation({
    username: toValue(username),
    password: toValue(password),
  })
}
</script>

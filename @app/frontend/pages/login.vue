<template>
  <form action="post" @submit.prevent="login()">
    <label for="loginInputUsername" class="block">
      <span>Login-Name</span>
      <input id="loginInputUsername" v-model="username" type="text" />
    </label>
    <label for="loginInputPassword" class="block">
      <span>Passwort</span>
      <input id="loginInputPassword" v-model="password" type="password" />
    </label>
    <button type="submit">ok</button>
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

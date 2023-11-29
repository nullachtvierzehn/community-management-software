<template>
  <form action="post" @submit.prevent="login()">
    <label for="username-field"><input v-model="username" type="text" /></label>
    <label for="password-field"
      ><input v-model="password" type="password"
    /></label>
    <button type="submit">ok</button>
  </form>
  <pre v-if="error">{{ error }}</pre>
  <pre v-if="data">{{ data }}</pre>
</template>

<script lang="ts" setup>
import { useLoginMutation } from '~/graphql'

const username = ref('timo11')
const password = ref('12345678')
const { data, executeMutation, error } = useLoginMutation()

async function login() {
  await executeMutation({
    username: toValue(username),
    password: toValue(password),
  })
}
</script>

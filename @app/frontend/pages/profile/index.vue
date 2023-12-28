<template>
  <template v-if="user">
    <h1>Hallo {{ user.username }}</h1>
    <p>Du bist eingeloggt.</p>
    <div class="btn-bar">
      <button class="btn btn_primary" @click="logout()">ausloggen</button>
      <NuxtLink class="btn btn_primary" to="/profile/change-password"
        >Passwort ändern</NuxtLink
      >
    </div>
  </template>
  <template v-else>
    <h1>Bitte einloggen</h1>
  </template>
</template>

<script setup lang="ts">
import { useLogoutMutation } from '~/graphql'

definePageMeta({
  layout: 'page',
  middleware: ['auth'],
})

const user = await useCurrentUser()
const router = useRouter()
const { executeMutation: logoutMutation } = useLogoutMutation()

async function logout() {
  await logoutMutation({})
  router.push('/login')
}
</script>

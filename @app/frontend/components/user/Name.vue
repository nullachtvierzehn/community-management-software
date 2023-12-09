<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div v-if="profile" class="short-profile">
    <div class="short-profile__username">{{ profile.username }}</div>
  </div>
  <div v-else class="short-profile short-profile__missing">
    <div class="short-profile__username short-profile__username_imputed">
      [[ gelöscht ]]
    </div>
  </div>
</template>

<script setup lang="ts">
import { type ShortProfileFragment } from '~/graphql'
defineProps<{
  profile?: ShortProfileFragment | null
}>()
</script>

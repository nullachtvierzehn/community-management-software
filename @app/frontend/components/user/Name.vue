<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div v-if="profile" class="short-profile__username">
    {{ profile.username }}
  </div>
  <div v-else class="short-profile__username short-profile__username_imputed">
    [[ gelöscht ]]
  </div>
</template>

<script setup lang="ts">
import { type ShortProfileFragment } from '~/graphql'
defineProps<{
  profile?: ShortProfileFragment | null
}>()
</script>

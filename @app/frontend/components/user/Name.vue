<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <component :is="tag" v-if="profile">
    <span class="short-profile__username">{{ profile.username }}</span
    >&nbsp;<span v-if="isMe && tagMine">(ich)</span>
  </component>
  <component
    :is="tag"
    v-else
    class="short-profile__username short-profile__username_imputed"
  >
    [[ gelöscht ]]
  </component>
</template>

<script setup lang="ts">
import { type ShortProfileFragment } from '~/graphql'

const props = withDefaults(
  defineProps<{
    profile?: ShortProfileFragment | null
    tagMine?: boolean
    tag?: string
  }>(),
  { tag: 'div', profile: null }
)

const currentUser = await useCurrentUser()
const isMe = computed(
  () => currentUser.value?.id && currentUser.value.id === props.profile?.id
)
</script>

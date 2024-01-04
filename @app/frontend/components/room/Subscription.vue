<template>
  <div class="subscription">
    <UserName class="subscription__username" :profile="value.subscriber" />
    <div class="subscription__date">
      {{ formatDate(value.createdAt, 'DD.MM.YY') }}
    </div>
    <select
      ref="roleSelect"
      v-model="role"
      class="subscription__role"
      :disabled="fetching"
    >
      <option value="BANNED">Gebannt</option>
      <option value="PROSPECT">Kandidat:in</option>
      <option value="MEMBER">Mitglied</option>
      <option value="MODERATOR">Moderator</option>
      <option value="ADMIN">Admin</option>
    </select>
  </div>
</template>

<script setup lang="ts">
import {
  type ShortRoomSubscriptionFragment,
  useUpdateRoomSubscriptionMutation,
} from '~/graphql'

const { executeMutation, fetching } = useUpdateRoomSubscriptionMutation()

const props = defineProps<{
  value: ShortRoomSubscriptionFragment
}>()

const role = ref(props.value.role)
const roleSelect = ref<HTMLSelectElement>()

watch(role, async (newRole, oldRole) => {
  const { error } = await executeMutation({
    oldId: props.value.id,
    patch: { role: newRole },
  })
  if (error) {
    role.value = oldRole
    throw error
  }
})
</script>

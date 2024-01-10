<template>
  <div class="subscription">
    <div class="subscription__username flex justify-between">
      <UserName :profile="value.subscriber" />
      <button
        v-if="value.subscriberId === mySubscription?.subscriberId"
        @click="unsubscribe()"
      >
        <i class="ri-close-circle-line"></i>
      </button>
    </div>
    <div class="subscription__date">
      {{ formatDate(value.createdAt, 'DD.MM.YY') }}
    </div>
    <select
      v-if="
        mySubscription?.role &&
        orderOfRole(mySubscription.role) >= orderOfRole('MODERATOR')
      "
      ref="roleSelect"
      v-model="role"
      class="subscription__role"
      :disabled="fetching"
    >
      <option value="BANNED">Gebannt</option>
      <option value="PROSPECT">Kandidat:in</option>
      <option value="MEMBER">Mitglied</option>
      <option
        value="MODERATOR"
        :disabled="orderOfRole(mySubscription.role) < orderOfRole('MODERATOR')"
      >
        Moderator
      </option>
      <option
        value="ADMIN"
        :disabled="orderOfRole(mySubscription.role) < orderOfRole('ADMIN')"
      >
        Admin
      </option>
    </select>
    <div v-else class="subscription__role">
      <span v-if="role === 'BANNED'">Gebannt</span>
      <span v-else-if="role === 'PROSPECT'">Kandidat:in</span>
      <span v-else-if="role === 'MEMBER'">Mitglied</span>
      <span v-else-if="role === 'MODERATOR'">Moderator</span>
      <span v-else-if="role === 'ADMIN'">Admin</span>
    </div>
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
const { mySubscription, unsubscribe } = useRoomWithTools({
  id: computed(() => props.value.roomId),
})

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

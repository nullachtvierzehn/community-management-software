<template>
  <section v-if="room?.abstract" class="container mx-auto">
    <h1 class="text-2xl mb-4">Über</h1>
    <p>{{ room.abstract }}</p>
  </section>

  <section
    v-if="
      subscription && orderOfRole(subscription.role) >= orderOfRole('MODERATOR')
    "
    class="container mx-auto"
  >
    <h1 class="text-2xl mb-4">Raum-Einstellungen</h1>
    <form class="form-grid" @submit="onSubmit">
      <div class="form-input">
        <label>Sichtbar für</label>
        <select v-model="isVisibleFor" v-bind="isVisibleForAttrs">
          <option value="SUBSCRIBERS">Mitglieder</option>
          <option value="ORGANIZATION_MEMBERS">In der Organisation</option>
          <option value="SIGNED_IN_USERS">Angemeldete User</option>
          <option value="PUBLIC">Alle</option>
        </select>
      </div>

      <div class="form-input">
        <label>Beiträge sichtbar für</label>
        <select v-model="itemsAreVisibleFor" v-bind="itemsAreVisibleForAttrs">
          <option value="BANNED">Verbannte</option>
          <option value="PUBLIC">Alle</option>
          <option value="PROSPECT">Mitgliedschafts-Kandidat:innen</option>
          <option value="MEMBER">Mitglieder</option>
          <option value="MODERATOR">Moderator:innen</option>
          <option value="ADMIN">Administrator:innen</option>
        </select>
      </div>

      <button class="btn btn_primary">abschicken</button>
    </form>
  </section>
</template>

<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod'
import { useForm } from 'vee-validate'
import { z } from 'zod'

definePageMeta({
  name: 'room/about',
})

const { room, update } = await useRoomWithTools()
const subscription = await useSubscription()

const { defineField, handleSubmit } = useForm({
  validationSchema: toTypedSchema(
    z.object({
      isVisibleFor: z
        .enum([
          'SUBSCRIBERS',
          'ORGANIZATION_MEMBERS',
          'SIGNED_IN_USERS',
          'PUBLIC',
        ])
        .or(z.null()),
      itemsAreVisibleFor: z
        .enum(['BANNED', 'PUBLIC', 'PROSPECT', 'MEMBER', 'MODERATOR', 'ADMIN'])
        .or(z.null()),
    })
  ),
  initialValues: {
    isVisibleFor: room.value?.isVisibleFor ?? null,
    itemsAreVisibleFor: room.value?.itemsAreVisibleFor ?? null,
  },
})

const [isVisibleFor, isVisibleForAttrs] = defineField('isVisibleFor')
const [itemsAreVisibleFor, itemsAreVisibleForAttrs] =
  defineField('itemsAreVisibleFor')

const onSubmit = handleSubmit(async (values) => {
  await update(values)
})
</script>

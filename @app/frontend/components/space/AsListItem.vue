<template>
  <div class="border-2 border-gray-300 px-4 py-2 rounded-lg">
    <div v-if="modelValue.name" class="text-xl font-bold">
      {{ modelValue.name }}
    </div>
    <div v-else class="text-xl font-bold">
      Raum {{ modelValue.id.substring(0, 5) }}…
    </div>

    <div
      class="flex flex-wrap justify-between border-t border-gray-300 -mx-4 px-4 mt-2 pt-2"
    >
      <ul class="flex gap-3">
        <li class="flex gap-1">
          <i class="block ri-group-line"></i>
          <span class="block">{{ modelValue.nSubscriptions }}</span>
          <span class="block sr-only">Mitglieder</span>
        </li>
        <li class="flex gap-1">
          <i class="block ri-chat-3-line"></i>
          <span class="block">{{ modelValue.nPosts }}</span>
          <span class="block sr-only">Nachrichten</span>
        </li>
        <li
          v-if="
            modelValue.mySubscription && modelValue.nPostsSinceLastVisit > '0'
          "
          class="flex gap-1"
        >
          <i class="block ri-chat-history-line"></i>
          <span class="block">{{ modelValue.nPostsSinceLastVisit }}</span>
          <span class="block sr-only">
            Nachrichten seit dem letzten Besuch.
          </span>
        </li>
      </ul>

      <ul class="flex gap-3">
        <!-- notifications -->
        <li v-if="modelValue.mySubscription?.notifications === 'IMMEDIATE'">
          <i class="ri-notification-line"></i>
          <span class="sr-only"
            >Sie werden bei neuen Nachrichten per E-Mail benachrichtigt.</span
          >
        </li>
        <li v-else-if="modelValue.mySubscription?.notifications === 'SILENCED'">
          <i class="ri-notification-off-line"></i>
          <span class="sr-only"
            >Dieser Raum ist stumm: Sie erhalten keine Nachrichten per
            E-Mail.</span
          >
        </li>

        <!-- visibility -->
        <li v-if="!modelValue.isPublic">
          <i class="ri-chat-private-line"></i>
          <span class="sr-only">privater Raum</span>
        </li>

        <!-- my role/subscription -->
        <!-- TODO: Refactor using capabilities
        <template v-if="modelValue.mySubscription">
          <li
            v-if="
              orderOfRole(modelValue.mySubscription.role) >=
              orderOfRole('ADMIN')
            "
          >
            <i class="ri-vip-crown-2-line"></i>
            <span class="sr-only">Sie sind Administrator</span>
          </li>
          <li
            v-else-if="
              orderOfRole(modelValue.mySubscription.role) >=
              orderOfRole('MODERATOR')
            "
          >
            <i class="ri-vip-crown-2-line"></i>
            <span class="sr-only">Sie sind Moderator</span>
          </li>
          <li
            v-else-if="
              orderOfRole(modelValue.mySubscription.role) >=
              orderOfRole('MEMBER')
            "
          >
            <i class="ri-user-follow-line"></i>
            <span class="sr-only">Sie sind Mitglied</span>
          </li>
        </template>
        -->
      </ul>
    </div>
  </div>
</template>

<script setup lang="ts">
import { type FetchSpacesQuery } from '~/graphql'

type Space = NonNullable<FetchSpacesQuery['spaces']>['nodes'][0]

defineProps<{ modelValue: Space }>()
</script>

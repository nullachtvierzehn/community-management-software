<template>
  <template v-if="user">
    <h1>Hallo {{ user.username }}</h1>
    <p>Diese Seite im</p>
  </template>
  <template v-else>
    <h1>Hallo und herzlich willkommen!</h1>
    <p>
      Diese Seite wird aktuell überarbeitet und getestet. Vielen Dank, wenn Sie
      Interesse haben und sich beteiligen!
    </p>
    <div class="grid grid-cols-[1fr_2fr] gap-2">
      <p>Neu hier?</p>
      <NuxtLink to="/register" class="btn btn_primary">Zur Anmeldung</NuxtLink>
      <p>Schon Angemeldet?</p>
      <NuxtLink to="/login" class="btn btn_primary">Einloggen</NuxtLink>
    </div>
    <hr class="border-gray-700 my-4" />

    <section id="Rechtliches" class="text-sm text-gray-700">
      <p>
        <strong>Kontakt:</strong> Wende Dich an
        <a href="mailto:mail@a-friend.org">mail@a-friend.org</a>, wenn Du
        mittesten möchtest oder Fragen hast.
        <NuxtLink to="/imprint">Zum Impressum...</NuxtLink>
      </p>
      <p>
        <strong>Datenschutz: </strong>
        Bis zur Registrierung zeichnet diese Seite keine Daten von Ihnen auf.
        Verantwortlich für den Datenschutz ist die Betreiberin dieser Seite, die
        Firma
        <a href="https://www.nullachtvierzehn.de" target="_blank"
          >Nullachtvierzehn UG (haftungsbeschränkt)</a
        >. <NuxtLink to="/privacy">Zum Datenschutzhinweis...</NuxtLink>
      </p>
    </section>
  </template>
</template>

<script setup lang="ts">
import { useFetchRoomsQuery } from '~/graphql'

definePageMeta({
  layout: 'page',
})

const user = useCurrentUser()

const { data: dataOfSubscribedRooms } = await useFetchRoomsQuery({
  variables: { filter: { mySubscriptionId: { isNull: false } } },
})

const subscribedRooms = computed(
  () => dataOfSubscribedRooms.value?.rooms?.nodes ?? []
)
</script>

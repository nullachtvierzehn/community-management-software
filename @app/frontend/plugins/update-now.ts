import { now } from '~/utils/format-date'

export default defineNuxtPlugin((_nuxt) => {
  now.value = new Date()
})

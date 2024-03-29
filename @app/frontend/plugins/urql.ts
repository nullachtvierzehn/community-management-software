import { Client, createClient, fetchExchange, ssrExchange } from '@urql/core'
import { devtoolsExchange } from '@urql/devtools'
import { cacheExchange, type SSRData } from '@urql/vue'
import { ref } from 'vue'

export default defineNuxtPlugin((nuxt) => {
  const ssrKey = '__URQL_DATA__'
  const requestHeaders = useRequestHeaders(['cookie', 'authorization'])

  const ssr = ssrExchange({
    isClient: process.client,
    initialState: process.client
      ? (nuxt.payload[ssrKey] as SSRData)
      : undefined,
  })

  // when app is created in browser, restore SSR state from nuxt payload
  if (process.client) {
    nuxt.hook('app:created', () => {
      const data = markRaw(nuxt.payload[ssrKey] as SSRData)
      console.debug('restored graphql data from server', data)
      ssr.restoreData(data)
    })
  }

  // when app has rendered in server, send SSR state to client
  if (process.server) {
    nuxt.hook('app:rendered', () => {
      const data = markRaw(ssr.extractData())
      console.debug('restore graphql data for client', data)
      nuxt.payload[ssrKey] = data
    })
  }

  const url = new URL(
    '/graphql',
    process.client
      ? window.location.href
      : process.env.ROOT_URL ??
        `http://localhost: ${process.env.FRONTEND_PORT ?? 3000}`
  )

  const client = createClient({
    url: url.toString(),
    exchanges: [
      ...(process.env.NODE_ENV !== 'production' ? [devtoolsExchange] : []),
      cacheExchange,
      ssr, // Add `ssr` in front of the `fetchExchange`
      fetchExchange,
    ],
    fetchOptions() {
      const headers: HeadersInit = { ...requestHeaders }
      console.debug('delegate request headers to graphql', requestHeaders)
      //headers["csrf-token"] = requestHeaders
      return { headers }
    },
  })

  nuxt.provide('urql', client)
  nuxt.vueApp.provide('$urql', ref(client))
})

declare module '#app' {
  interface NuxtApp {
    $urql: Client
  }
}

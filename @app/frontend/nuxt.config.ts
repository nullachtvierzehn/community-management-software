// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt-alt/proxy',
    '@nuxtjs/i18n',
    '@vueuse/nuxt',
    '@nuxtjs/tailwindcss',
  ],
  i18n: {
    locales: ['de'],
    defaultLocale: 'de',
  },
  sourcemap: {
    server: true,
    client: true,
  },
  devtools: { enabled: true },
  // `proxy` is added by module @nuxt-alt/proxy, see https://github.com/nuxt-alt/proxy
  proxy: {
    proxies: {
      '/graphql': { target: 'http://localhost:3001', changeOrigin: true },
      '/graphiql': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
})

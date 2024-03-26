import { type ModuleOptions as TailwindOptions } from '@nuxtjs/tailwindcss'
import type autoprefixer from 'autoprefixer'
import { type Options as CssNanoOptions } from 'cssnano'
import { config as loadConfig } from 'dotenv'
import findConfig from 'find-config'
import { createProxyServer } from 'httpxy'

const configPath = findConfig('.env')
if (configPath) loadConfig({ path: configPath })

const backendUrl = new URL(
  '',
  process.client
    ? window.location.href
    : process.env.ROOT_URL ?? 'http://localhost:3001'
)

backendUrl.port = process.env.NUXT_BACKEND_PORT ?? '3001'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  css: [
    '@vueform/multiselect/themes/default.css',
    '@fontsource-variable/merriweather-sans/wght-italic.css',
    '@fontsource-variable/merriweather-sans/wght.css',
    '@fontsource/merriweather/400.css',
    '@fontsource/merriweather/400-italic.css',
    '@fontsource/merriweather/700.css',
    '@fontsource/merriweather/700-italic.css',
    'remixicon/fonts/remixicon.css',
  ],
  dayjs: {
    locales: ['de'],
    plugins: ['relativeTime', 'utc', 'timezone'],
    defaultLocale: 'de',
    defaultTimezone: 'Europe/Berlin',
  },
  devtools: { enabled: true },
  i18n: {
    locales: ['de'],
    defaultLocale: 'de',
  },
  modules: [
    //'@nuxt-alt/proxy',
    '@nuxtjs/i18n',
    'dayjs-nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/tailwindcss',
    '@vee-validate/nuxt',
  ],
  // `proxy` is added by module @nuxt-alt/proxy, see https://github.com/nuxt-alt/proxy
  routeRules: {
    // https://github.com/nuxt/nuxt/issues/19325#issuecomment-1447909255
    '/socket.io/**': { proxy: { to: `${backendUrl.toString()}socket.io/**` } },
    //'/graphql': { proxy: { to: `${backendUrl.toString()}/graphql` } },
    '/graphql/**': { proxy: { to: `${backendUrl.toString()}graphql/**` } },
    '/graphiql/**': { proxy: { to: `${backendUrl.toString()}graphiql/**` } },
    '/backend/**': { proxy: { to: `${backendUrl.toString()}backend/**` } },
  },
  hooks: {
    listen(server) {
      const proxy = createProxyServer({
        target: { host: 'localhost', port: 3001 },
        secure: false,
        changeOrigin: true,
        ws: true,
      })
      // https://github.com/nuxt/cli/issues/107#issuecomment-1850751905
      // https://gist.github.com/ucw/67f7291c64777fb24341e8eae72bcd24
      server.on('upgrade', (req, socket, head) => {
        if (
          req.url?.startsWith('/socket.io') ||
          req.url?.startsWith('/backend/ws')
        )
          proxy.ws(req, socket as any, head as any)
      })
    },
  },
  postcss: {
    plugins: {
      'tailwindcss/nesting': {},
      tailwindcss: {} satisfies Partial<TailwindOptions>,
      autoprefixer: {} satisfies Partial<autoprefixer.Options>,
      cssnano: {} satisfies Partial<CssNanoOptions>,
    },
  },
  sourcemap: {
    server: true,
    client: true,
  },
  ssr: true,
  veeValidate: {
    // disable or enable auto imports
    autoImports: true,
    // Use different names for components
    componentNames: {
      Form: 'VeeForm',
      Field: 'VeeField',
      FieldArray: 'VeeFieldArray',
      ErrorMessage: 'VeeErrorMessage',
    },
  },
})

import { type ModuleOptions as TailwindOptions } from '@nuxtjs/tailwindcss'
import type autoprefixer from 'autoprefixer'
import { type Options as CssNanoOptions } from 'cssnano'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt-alt/proxy',
    '@nuxtjs/i18n',
    'dayjs-nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/tailwindcss',
  ],
  i18n: {
    locales: ['de'],
    defaultLocale: 'de',
  },
  dayjs: {
    locales: ['de'],
    plugins: ['relativeTime', 'utc', 'timezone'],
    defaultLocale: 'de',
    defaultTimezone: 'Europe/Berlin',
  },
  sourcemap: {
    server: true,
    client: true,
  },
  ssr: true,
  devtools: { enabled: true },
  css: [
    '@vueform/multiselect/themes/default.css',
    '@fontsource-variable/merriweather-sans/wght-italic.css',
    '@fontsource-variable/merriweather-sans/wght.css',
    '@fontsource/merriweather/400.css',
    '@fontsource/merriweather/400-italic.css',
    '@fontsource/merriweather/700.css',
    '@fontsource/merriweather/700-italic.css',
  ],
  postcss: {
    plugins: {
      'tailwindcss/nesting': {},
      tailwindcss: {} satisfies Partial<TailwindOptions>,
      autoprefixer: {} satisfies Partial<autoprefixer.Options>,
      cssnano: {} satisfies Partial<CssNanoOptions>,
    },
  },
  // `proxy` is added by module @nuxt-alt/proxy, see https://github.com/nuxt-alt/proxy
  proxy: {
    proxies: {
      '/backend/files': { target: 'http://localhost:3001', changeOrigin: true },
      '/graphql': { target: 'http://localhost:3001', changeOrigin: true },
      '/graphiql': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
})

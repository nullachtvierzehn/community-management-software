import { CurrentUserDocument, type CurrentUserQuery } from '~/graphql'

export default defineNuxtRouteMiddleware(async (to) => {
  // https://nuxt.com/docs/guide/directory-structure/middleware#when-middleware-runs
  const app = useNuxtApp()

  // check, if current user is signed in
  const { data, error } = await app.$urql.query<CurrentUserQuery>(
    CurrentUserDocument,
    {},
    { requestPolicy: 'cache-and-network' }
  )

  // redirect to login, if check fails or current user is signed out
  if (error || !data?.currentUser) {
    return navigateTo({ path: '/login', query: { next: to.fullPath } })
  }
})

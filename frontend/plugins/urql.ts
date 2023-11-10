import {
  createClient,
  cacheExchange,
  ssrExchange,
  fetchExchange,
  Client,
} from "@urql/core";
import { defineNuxtPlugin } from "#app";
import { ref } from "vue";
import type { SSRData } from "@urql/vue";

export default defineNuxtPlugin((nuxt) => {
  const ssrKey = "__URQL_DATA__";

  const ssr = ssrExchange({
    isClient: process.client,
    initialState: process.client
      ? (nuxt.payload[ssrKey] as SSRData)
      : undefined,
  });

  // when app is created in browser, restore SSR state from nuxt payload
  if (process.client) {
    nuxt.hook("app:created", () => {
      const data = markRaw(nuxt.payload[ssrKey] as SSRData);
      console.debug("restored graphql data from server", data);
      ssr.restoreData(data);
    });
  }

  // when app has rendered in server, send SSR state to client
  if (process.server) {
    nuxt.hook("app:rendered", () => {
      const data = markRaw(ssr.extractData());
      console.debug("restore graphql data for client", data);
      nuxt.payload[ssrKey] = data;
    });
  }

  const client = createClient({
    url: "http://localhost:3000/graphql",
    exchanges: [
      cacheExchange,
      ssr, // Add `ssr` in front of the `fetchExchange`
      fetchExchange,
    ],
  });

  nuxt.provide("urql", client);
  nuxt.vueApp.provide("$urql", ref(client));
});

declare module "#app" {
  interface NuxtApp {
    $urql: Client;
  }
}

import { run } from 'graphile-worker'

import preset from './graphile.config.js'

async function main() {
  // Run a worker to execute jobs:
  const runner = await run({
    preset,
  })

  // Immediately await (or otherwise handle) the resulting promise, to avoid
  // "unhandled rejection" errors causing a process crash in the event of
  // something going wrong.
  await runner.promise

  // If the worker exits (whether through fatal error or otherwise), the above
  // promise will resolve/reject.
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})

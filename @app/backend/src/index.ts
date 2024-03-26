import './routes/index.js'

import { app } from './app.js'
import { ownerPool, pool } from './database/pool.js'
import { grafservInstance, preset } from './graphile/index.js'

// Add the Grafserv instance's route handlers to the Fastify app
grafservInstance.addTo(app).catch((e: any) => {
  console.error(e)
  process.exit(1)
})

// Run cleanup-jobs when the app is closed.
app.addHook('onClose', (_instance, done) => {
  // Then, disconnect the database pools.
  Promise.allSettled([pool.end(), ownerPool.end()]).then(
    ([poolEnded, ownerPoolEnded]) => {
      console.log('database pools disconnected')
      if (poolEnded.status === 'rejected')
        done(
          new Error(
            `Failed to end database pool: ${poolEnded.reason.toString()}`
          )
        )
      else if (ownerPoolEnded.status === 'rejected')
        done(
          new Error(
            `Failed to end database pool (owner): ${ownerPoolEnded.reason.toString()}`
          )
        )
      else done()
    }
  )
})

// Start the Fastify server
app.listen({ port: preset.grafserv?.port ?? 5678 }, (err, address) => {
  if (err) {
    app.log.error(err)
    process.exit(1)
  }
  console.log(`Server is now listening on ${address}`)
})

// Implement graceful shutdown.
let shuttingDownGracefully = false
async function gracefulShutdown() {
  if (shuttingDownGracefully) {
    console.log('Shutting down forcefully.')
    process.exit(1)
  } else {
    console.log('Shutting down gracefully.')
    shuttingDownGracefully = true
    await app.close()
    process.exit(0)
  }
}

process.on('SIGINT', gracefulShutdown)
process.on('SIGTERM', gracefulShutdown)
process.on('exit', (code) => console.log(`process exit code ${code}`))

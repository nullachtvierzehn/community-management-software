import './login.js'
import './registration.js'

//import { type FastifyPluginAsyncJsonSchemaToTs } from '@fastify/type-provider-json-schema-to-ts'
import { app } from '../app.js'

app.get('/', (_req, _res) => {
  _res.send('Hello World!')
})

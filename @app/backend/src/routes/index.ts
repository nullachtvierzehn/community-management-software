import './login.js'
import './registration.js'

import { app } from '../app.js'

export default app.get('/', async (_request, _reply) => {
  return { hello: 'world' }
})

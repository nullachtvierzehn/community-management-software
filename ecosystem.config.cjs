const { config } = require('dotenv')
const { parsed: env } = config()

if (!env) throw new Error('no parsed env')

/**
 * @type {import('pm2').StartOptions}
 */
module.exports = {
  apps: [
    {
      name: 'frontend',
      script: 'server/index.mjs',
      interpreter: 'node',
      cwd: '@app/frontend/.output',
      env,
    },
    {
      name: 'backend',
      script: 'index.js',
      interpreter: 'node',
      cwd: '@app/backend/dist',
      env,
    },
    {
      name: 'python-worker',
      script: 'run.sh',
      cwd: './@app/python-worker',
      env,
    },
    {
      name: 'graphile-worker',
      script: 'index.js',
      interpreter: 'node',
      cwd: '@app/graphile-worker/dist',
      env,
    },
  ],
}

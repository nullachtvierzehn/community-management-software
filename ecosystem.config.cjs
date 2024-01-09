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
      watch: ['server/chunks', 'server/*.mjs', 'public'],
      interpreter: 'node',
      cwd: '@app/frontend/.output',
      env,
    },
    {
      name: 'backend',
      script: 'index.js', // Replace with the path to your second Node.js app
      watch: ['.'],
      interpreter: 'node',
      cwd: '@app/backend/dist',
      env,
    },
    {
      name: 'python-worker',
      script: 'run.sh',
      watch: ['python_worker'],
      cwd: './@app/python-worker',
      env,
    },
  ],
}

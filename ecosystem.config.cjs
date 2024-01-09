/**
 * @type {import('pm2').StartOptions}
 */
module.exports = {
  apps: [
    {
      name: 'frontend',
      script: 'server/index.mjs',
      //watch: true
      interpreter: 'node',
      cwd: '@app/frontend/.output',
    },
    {
      name: 'backend',
      script: 'index.js', // Replace with the path to your second Node.js app
      //watch: true,
      interpreter: 'node',
      cwd: '@app/backend/dist',
    },
    {
      name: 'python-worker',
      script: 'poetry',
      args: 'run -- procrastinate --app=python_worker.app worker --concurrency=5', // Replace 'my_script.py' with your Python script
      //watch: true,
      interpreter: '/bin/bash',
      cwd: '@app/python-worker',
    },
  ],
}

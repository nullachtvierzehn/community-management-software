import { config as loadConfig } from 'dotenv'
import findConfig from 'find-config'
import type {} from 'graphile-config'
import type {} from 'graphile-worker'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const configPath = findConfig('.env')
if (configPath) loadConfig({ path: configPath })

const preset: GraphileConfig.Preset = {
  worker: {
    connectionString: `postgres://${process.env.DATABASE_OWNER}:${process.env.DATABASE_OWNER_PASSWORD}@${process.env.DATABASE_HOST}:${process.env.DATABASE_PORT}/${process.env.DATABASE_NAME}`,
    maxPoolSize: 10,
    pollInterval: 2000,
    preparedStatements: true,
    schema: 'graphile_worker',
    crontabFile: `${__dirname}/crontab`,
    concurrentJobs: 5,
    fileExtensions: ['.js', '.cjs', '.mjs', '.ts', '.cts', '.mts', '.py'],
    taskDirectory: `${__dirname}/tasks`,
  },
}

export default preset

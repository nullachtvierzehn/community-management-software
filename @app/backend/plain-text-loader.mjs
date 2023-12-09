import { promises as fs } from 'fs'
import { fileURLToPath } from 'url'

async function load(url, context, defaultLoad) {
  if (url.endsWith('.txt') || url.endsWith('.mjml')) {
    const filePath = fileURLToPath(url)
    const content = await fs.readFile(filePath, 'utf8')
    return {
      format: 'module',
      source: `export default ${JSON.stringify(content)}`,
      shortCircuit: true, // Signal that the loader chain should end here
    }
  }
  // Fallback to default loader for other files
  return defaultLoad(url, context, defaultLoad)
}

export { load }

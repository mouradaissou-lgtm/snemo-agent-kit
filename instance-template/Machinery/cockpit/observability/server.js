// Tiny observability server (instance stub): serves the HTML dashboard.
// No dependencies: node server.js  (then open http://127.0.0.1:7788)
// Port via DSH_OBS_PORT (default 7788). Aucun domaine.
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const ROOT = dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.DSH_OBS_PORT || 7788)
const server = createServer(async (req, res) => {
  try {
    const html = await readFile(join(ROOT, 'index.html'))
    res.writeHead(200, { 'Content-Type': 'text/html' })
    res.end(html)
  } catch {
    res.writeHead(404); res.end('not found')
  }
})
server.listen(PORT, '127.0.0.1', () => console.log(`Observability (instance) sur http://127.0.0.1:${PORT}`))

#!/usr/bin/env node
// Agent cockpit server (instance standalone) — serves the dashboard + /monitor JSON.
// URL: http://127.0.0.1:8003/dashboard.html  (port via DSH_PORT, default 8003)
// Le chemin de l'instance est résolu depuis ce fichier (<instance>/Machinery/cockpit/),
// surchargé par DSH_INSTANCE_DIR. Aucun domaine.
const http = require('node:http')
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')

const ROOT = __dirname
const INSTANCE = process.env.DSH_INSTANCE_DIR || path.resolve(__dirname, '..', '..')
const PORT = Number(process.env.DSH_PORT || 8003)
const HOST = '127.0.0.1'

function monitorJson() {
  try {
    return execFileSync('python3', [path.join(ROOT, 'monitor.py')],
      { encoding: 'utf8', env: { ...process.env, DSH_INSTANCE_DIR: INSTANCE } })
  } catch (e) {
    return JSON.stringify({ error: String(e.stderr || e) })
  }
}

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json', '.css': 'text/css' }

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0]
  if (url === '/monitor') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(monitorJson())
    return
  }
  // /spec : conformité CONTRE NOTRE SPEC — catalogue des fonctions + matrice de couverture.
  if (url === '/spec') {
    try {
      const catP = path.join(INSTANCE, 'tests', 'spec_catalog.json')
      const covP = path.join(INSTANCE, 'tests', 'spec_coverage.json')
      const cat = fs.readFileSync(catP, 'utf8')
      const cov = fs.readFileSync(covP, 'utf8')
      const payload = { catalog: JSON.parse(cat), coverage: JSON.parse(cov || '{}') }
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(payload))
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ error: String(e) }))
    }
    return
  }
  let p = url === '/' ? '/dashboard.html' : url
  const file = path.join(ROOT, p)
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end('not found'); return
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'text/plain' })
  fs.createReadStream(file).pipe(res)
})

server.listen(PORT, HOST, () => {
  console.log(`Cockpit (instance) sur http://${HOST}:${PORT}/dashboard.html  (instance: ${INSTANCE})`)
})

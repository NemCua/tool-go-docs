import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
const root = new URL('.', import.meta.url).pathname;
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' };
createServer(async (req, res) => {
  try { if(req.url==='/api/test-text'){const body=await readFile(join(root,'..','input','testText.txt'));res.writeHead(200,{'Content-Type':'text/plain; charset=utf-8'});return res.end(body)} const file = req.url === '/' ? 'index.html' : req.url.slice(1); const body = await readFile(join(root, file)); res.writeHead(200, {'Content-Type': types[extname(file)] || 'text/plain'}); res.end(body); }
  catch { res.writeHead(404); res.end('Not found'); }
}).listen(4173, () => console.log('HumanTyper Settings: http://localhost:4173'));

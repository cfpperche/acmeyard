// Minimal fake Chrome DevTools /json endpoint for spec-152.2 adopt detection tests.
// Serves /json/version and /json with a single page target whose url = $CDP_URL.
const http = require('http');
const PORT = process.env.FAKE_CDP_PORT || 9230;
const URLV = process.env.CDP_URL || 'about:blank';
http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url === '/json/version') { res.end(JSON.stringify({ Browser: 'FakeChrome/1.0' })); return; }
  if (req.url.startsWith('/json')) { res.end(JSON.stringify([{ type: 'page', url: URLV }])); return; }
  res.writeHead(404); res.end('[]');
}).listen(PORT, () => console.error('fake-cdp on ' + PORT + ' url=' + URLV));

// Synthetic auth host for the spec-152 auth-gated dogfood slice.
// Zero deps, zero real credentials. Cookie-session: demo/secret.
const http = require('http');
const PORT = process.env.AUTH_PORT || 8137;
const page = (title, body) =>
  `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${title}</title></head><body>${body}</body></html>`;
const login = page('Login', `<main><h1>Sign in</h1>
  <form method="POST" action="/login">
    <label for="username">User</label><input id="username" name="username">
    <label for="password">Pass</label><input id="password" name="password" type="password">
    <button id="submit" type="submit">Sign in</button>
  </form></main>`);
const dash = page('Account', `<main><h1>Account</h1><p>Welcome, demo — you are authenticated.</p></main>`);
http.createServer((req, res) => {
  const cookie = req.headers.cookie || '';
  const authed = /(?:^|;\s*)session=ok(?:;|$)/.test(cookie);
  if (req.method === 'POST' && req.url === '/login') {
    let b = ''; req.on('data', c => b += c); req.on('end', () => {
      const p = new URLSearchParams(b);
      if (p.get('username') === 'demo' && p.get('password') === 'secret') {
        res.writeHead(302, { 'Set-Cookie': 'session=ok; Path=/; Max-Age=3600; HttpOnly', Location: '/dashboard' }); res.end();
      } else { res.writeHead(401); res.end('bad creds'); }
    }); return;
  }
  if (req.url === '/dashboard') {
    if (authed) { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end(dash); }
    else { res.writeHead(302, { Location: '/login' }); res.end(); }
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html' }); res.end(login);
}).listen(PORT, () => console.error('auth-server on ' + PORT));

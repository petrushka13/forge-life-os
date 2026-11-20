'use strict';
const crypto = require('node:crypto');
function endpoint(value) {
  const url = new URL(value);
  if (url.username || url.password || url.hash || url.search || url.pathname !== '/v1/events/coding' ||
      !(url.protocol === 'https:' || (url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname)))) throw new Error('Use HTTPS /v1/events/coding, or loopback for development.');
  return url.href;
}
function sample({ now, lastEdit, focused, trusted, project, previous }) {
  // One full active minute maximum per tick; idle time, sleep and background windows do not count.
  if (!focused || !trusted || !project || lastEdit <= previous || now - lastEdit > 60000 || now - previous < 60000 || now - previous > 90000) return null;
  return {id: crypto.randomUUID(), kind: 'coding_session', project: project.slice(0, 200), timestamp: new Date(now).toISOString(), start: new Date(now - 60000).toISOString(), end: new Date(now).toISOString(), minutes: 1};
}
module.exports = {endpoint, sample};

import { createServer } from 'node:http';
import { APIError } from './quota.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
async function readBody(request) {
  const chunks = []; let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 8192) throw new APIError(413, 'too_large', 'Please use a shorter description.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new APIError(400, 'invalid_json', 'The request could not be read.'); }
}
function respond(response, status, data) {
  response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  response.end(JSON.stringify(data));
}

export function createAPI({ authorize, generate, quota, maxConcurrent = 2 }) {
  let activeGenerations = 0, activeRequests = 0;
  const server = createServer(async (request, response) => {
    if (request.url === '/health' && request.method === 'GET') { respond(response, 200, { ok: true }); return; }
    if (request.url !== '/v1/generations' || request.method !== 'POST') { respond(response, 404, { error: { code: 'not_found', message: 'Not found.' } }); return; }
    if (activeRequests >= 24) { respond(response, 503, { error: { code: 'busy', message: 'Please try again shortly.' } }); return; }
    activeRequests += 1;
    let reservedID, running = false;
    try {
      if (!request.headers['content-type']?.startsWith('application/json')) throw new APIError(415, 'content_type', 'Use JSON for this request.');
      const token = request.headers.authorization?.match(/^Bearer (\S+)$/)?.[1];
      if (!token || token.length > 16000) throw new APIError(401, 'unauthorized', 'An active Pro subscription is required.');
      const body = await readBody(request);
      if (!body || typeof body.prompt !== 'string' || body.prompt.trim().length < 3 || body.prompt.length > 1000 || !UUID.test(body.requestId ?? '') || !['simple', 'detailed'].includes(body.detail)) {
        throw new APIError(400, 'invalid_request', 'Add a description of 3–1000 characters and choose an outline style.');
      }
      const owner = await authorize(token);
      if (activeGenerations >= maxConcurrent) throw new APIError(503, 'busy', 'AI creation is busy. Please try again shortly.');
      const { cached } = quota.reserve(body.requestId, owner, body.prompt.trim(), body.detail);
      if (cached) { respond(response, 200, { imageBase64: cached, remaining: quota.remaining(owner), limit: quota.weeklyLimit }); return; }
      reservedID = body.requestId; running = true; activeGenerations += 1;
      const imageBase64 = await generate({ prompt: body.prompt.trim(), detail: body.detail, owner });
      if (typeof imageBase64 !== 'string' || imageBase64.length < 16 || imageBase64.length > 12_000_000) throw new APIError(502, 'invalid_image', 'The image service returned an invalid drawing. Please try again.');
      quota.complete(reservedID, imageBase64); reservedID = undefined;
      respond(response, 200, { imageBase64, remaining: quota.remaining(owner), limit: quota.weeklyLimit });
    } catch (error) {
      if (reservedID) quota.fail(reservedID);
      const known = error instanceof APIError;
      respond(response, known ? error.status : 500, { error: { code: known ? error.code : 'internal_error', message: known ? error.message : 'The drawing could not be created. Please try again.' } });
    } finally { activeRequests -= 1; if (running) activeGenerations -= 1; }
  });
  server.requestTimeout = 180000; server.headersTimeout = 15000;
  return server;
}

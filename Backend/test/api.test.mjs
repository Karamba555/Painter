import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { QuotaStore, APIError } from '../src/quota.mjs';
import { createAPI } from '../src/server.mjs';
import { openAIProvider } from '../src/providers.mjs';

const IMAGE = Buffer.from('fixture-image-for-tests').toString('base64');
function body(overrides = {}) { return { requestId: randomUUID(), prompt: 'A sleepy kitten', detail: 'simple', ...overrides }; }
async function fixture(t, options = {}) {
  const quota = new QuotaStore(':memory:', { weeklyLimit: 2, ...options.quotaOptions });
  let calls = 0;
  const server = createAPI({ quota, authorize: async token => {
    if (token !== 'verified-test-transaction') throw new APIError(403, 'pro_required', 'Pro required.');
    return 'verified-owner';
  }, generate: options.generate ?? (async () => { calls++; return IMAGE; }) });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(async () => { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); quota.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/generations`;
  return { quota, calls: () => calls, send: (payload, token = 'verified-test-transaction') => fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(payload) }) };
}

test('missing or invalid subscription never reaches the billable provider', async t => {
  const api = await fixture(t);
  assert.equal((await api.send(body(), '')).status, 401);
  assert.equal((await api.send(body(), 'fake')).status, 403);
  assert.equal(api.calls(), 0);
  assert.equal(api.quota.remaining('verified-owner'), 2);
});
test('successful requests persist and retries return the same image without another charge', async t => {
  const api = await fixture(t), request = body();
  const first = await api.send(request), second = await api.send(request);
  assert.equal(first.status, 200); assert.equal(second.status, 200);
  assert.deepEqual(await first.json(), { imageBase64: IMAGE, remaining: 1, limit: 2 });
  assert.deepEqual(await second.json(), { imageBase64: IMAGE, remaining: 1, limit: 2 });
  assert.equal(api.calls(), 1);
});
test('quota blocks the third request before the provider is called', async t => {
  const api = await fixture(t);
  await api.send(body()); await api.send(body());
  const response = await api.send(body());
  assert.equal(response.status, 429); assert.equal((await response.json()).error.code, 'quota_exceeded');
  assert.equal(api.calls(), 2);
});
test('reusing a request id with a changed description is rejected', async t => {
  const api = await fixture(t), request = body(); await api.send(request);
  assert.equal((await api.send({ ...request, prompt: 'A different flower' })).status, 409);
  assert.equal(api.calls(), 1);
});
test('provider failures refund user quota and a retry can complete', async t => {
  let attempts = 0;
  const api = await fixture(t, { generate: async () => { if (++attempts === 1) throw new APIError(502, 'unavailable', 'Try again.'); return IMAGE; } });
  const request = body();
  assert.equal((await api.send(request)).status, 502);
  assert.equal(api.quota.remaining('verified-owner'), 2);
  assert.equal((await api.send(request)).status, 200);
  assert.equal(api.quota.remaining('verified-owner'), 1);
});
test('pending reservation counts against quota and duplicate requests do not generate twice', async t => {
  let finish;
  const gate = new Promise(resolve => { finish = resolve; });
  const api = await fixture(t, { generate: async () => { await gate; return IMAGE; }, quotaOptions: { weeklyLimit: 1 } });
  const request = body(), first = api.send(request);
  while (api.quota.remaining('verified-owner') === 1) await new Promise(resolve => setImmediate(resolve));
  assert.equal((await api.send(request)).status, 409);
  assert.equal((await api.send(body())).status, 429);
  finish(); assert.equal((await first).status, 200);
});
test('malformed and oversized requests do not consume quota', async t => {
  const api = await fixture(t);
  assert.equal((await api.send(body({ prompt: '' }))).status, 400);
  assert.equal((await api.send(body({ prompt: 'x'.repeat(9000) }))).status, 413);
  assert.equal(api.calls(), 0);
});
test('quota and cached image survive a server restart; allowance resets after seven days', () => {
  const directory = mkdtempSync(join(tmpdir(), 'trace-quota-')); let now = 1_800_000_000_000;
  const path = join(directory, 'quota.sqlite'), id = randomUUID();
  let store = new QuotaStore(path, { weeklyLimit: 1, now: () => now });
  store.reserve(id, 'owner', 'kitten', 'simple'); store.complete(id, IMAGE); store.close();
  store = new QuotaStore(path, { weeklyLimit: 1, now: () => now });
  assert.equal(store.remaining('owner'), 0);
  assert.equal(store.reserve(id, 'owner', 'kitten', 'simple').cached, IMAGE);
  assert.throws(() => store.reserve(id, 'other-owner', 'kitten', 'simple'), /new request ID/);
  now += 7 * 86400000 + 1; assert.equal(store.remaining('owner'), 1);
  store.close(); rmSync(directory, { recursive: true });
});
test('global daily capacity includes failed provider attempts', () => {
  const store = new QuotaStore(':memory:', { dailyBudget: 1 });
  const first = randomUUID(); store.reserve(first, 'owner', 'kitten', 'simple'); store.fail(first);
  assert.throws(() => store.reserve(randomUUID(), 'another', 'flower', 'simple'), /capacity/);
  store.close();
});
test('provider uses server key, fixed image count, bounded style and privacy-preserving identifier', async () => {
  let captured;
  const provider = openAIProvider({ OPENAI_API_KEY: 'server-test-key' }, async (url, options) => { captured = { url, options }; return { ok: true, json: async () => ({ data: [{ b64_json: IMAGE }] }) }; });
  assert.equal(await provider({ prompt: 'a kitten', detail: 'simple', owner: 'hashed-owner' }), IMAGE);
  const sent = JSON.parse(captured.options.body);
  assert.equal(captured.url, 'https://api.openai.com/v1/images/generations');
  assert.equal(sent.n, 1); assert.equal(sent.safety_identifier, 'hashed-owner');
  assert.match(sent.prompt, /Beginner level/); assert.equal(sent.output_format, 'png');
  assert.equal(captured.options.headers.Authorization, 'Bearer server-test-key');
});

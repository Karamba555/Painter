import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { QuotaStore } from './quota.mjs';
import { createAPI } from './server.mjs';
import { appleAuthorizer, openAIProvider } from './providers.mjs';

const env = process.env;
function positive(name, fallback) { const value = Number(env[name] || fallback); if (!Number.isSafeInteger(value) || value < 1) throw new Error(`Invalid ${name}`); return value; }
const database = env.DATABASE_PATH || './data/trace-studio.sqlite';
mkdirSync(dirname(database), { recursive: true });
const authorize = appleAuthorizer(env);
const generate = openAIProvider(env);
const quota = new QuotaStore(database, { weeklyLimit: positive('AI_WEEKLY_LIMIT', 10), dailyBudget: positive('AI_DAILY_BUDGET', 100) });
const server = createAPI({ authorize, generate, quota, maxConcurrent: positive('AI_MAX_CONCURRENT', 2) });
server.listen(positive('PORT', 8080), env.HOST || '127.0.0.1', () => console.log('Trace Studio API ready.'));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
  server.close(() => { quota.close(); process.exit(0); });
  setTimeout(() => process.exit(1), 160000).unref();
});

import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { AppStoreServerAPIClient, Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { APIError } from './quota.mjs';

function required(env, name) { if (!env[name]?.trim()) throw new Error(`Missing required configuration: ${name}`); return env[name]; }
export function appleAuthorizer(env) {
  const environment = required(env, 'APPLE_ENVIRONMENT');
  if (!['Production', 'Sandbox'].includes(environment)) throw new Error('APPLE_ENVIRONMENT must be Production or Sandbox.');
  const appleEnvironment = environment === 'Production' ? Environment.PRODUCTION : Environment.SANDBOX;
  const bundleID = required(env, 'APPLE_BUNDLE_ID');
  const rootDir = required(env, 'APPLE_ROOT_CA_DIR');
  const roots = readdirSync(rootDir).filter(name => name.endsWith('.cer')).map(name => readFileSync(join(rootDir, name)));
  if (!roots.length) throw new Error('Add Apple root certificates (.cer) to APPLE_ROOT_CA_DIR.');
  const appID = environment === 'Production' ? Number(required(env, 'APPLE_APP_ID')) : undefined;
  if (environment === 'Production' && !Number.isSafeInteger(appID)) throw new Error('APPLE_APP_ID must be numeric.');
  const verifier = new SignedDataVerifier(roots, true, appleEnvironment, bundleID, appID);
  const client = new AppStoreServerAPIClient(readFileSync(required(env, 'APPLE_SIGNING_KEY_PATH'), 'utf8'), required(env, 'APPLE_KEY_ID'), required(env, 'APPLE_ISSUER_ID'), bundleID, appleEnvironment);
  const productID = required(env, 'APPLE_PRODUCT_ID');
  return async signedTransaction => {
    try {
      const submitted = await verifier.verifyAndDecodeTransaction(signedTransaction);
      if (!submitted.transactionId || submitted.productId !== productID) throw new Error('Invalid product');
      // Fetch fresh Apple data so a previously valid, now-refunded receipt cannot authorize generation.
      const current = await client.getTransactionInfo(submitted.transactionId);
      if (!current.signedTransactionInfo) throw new Error('No transaction');
      const transaction = await verifier.verifyAndDecodeTransaction(current.signedTransactionInfo);
      if (transaction.productId !== productID || transaction.bundleId !== bundleID || transaction.revocationDate || !transaction.expiresDate || transaction.expiresDate <= Date.now() || !transaction.originalTransactionId) throw new Error('Inactive subscription');
      return createHash('sha256').update(transaction.originalTransactionId).digest('hex');
    } catch { throw new APIError(403, 'pro_required', 'Your Pro subscription could not be verified. Restore purchases and try again.'); }
  };
}

export function openAIProvider(env, fetcher = fetch) {
  const key = required(env, 'OPENAI_API_KEY');
  const model = env.OPENAI_IMAGE_MODEL || 'gpt-image-2.5-flare';
  return async ({ prompt, detail, owner }) => {
    let response;
    try {
      response = await fetcher('https://api.openai.com/v1/images/generations', {
        method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(150000),
        body: JSON.stringify({ model, n: 1, size: '1024x1024', quality: 'medium', output_format: 'png', background: 'opaque', safety_identifier: owner,
          prompt: `Create a printable black line drawing on pure white paper, centered with generous margins. No text, watermark, border, grayscale shading or filled black areas. Clear clean contours suitable for tracing and coloring with a pencil. ${detail === 'simple' ? 'Beginner level: simplify shapes and use very few internal details.' : 'Detailed level: refined but traceable contours and decorative details.'} Subject requested by the artist: ${prompt}` })
      });
    } catch { throw new APIError(504, 'generation_timeout', 'The image service took too long. Please try again.'); }
    if (!response.ok) {
      if (response.status === 400) throw new APIError(422, 'prompt_rejected', 'This description could not be used. Try another subject or simpler wording.');
      throw new APIError(502, 'provider_unavailable', 'The image service is unavailable. Please try again later.');
    }
    const data = await response.json();
    return data.data?.[0]?.b64_json;
  };
}

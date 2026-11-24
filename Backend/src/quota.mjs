import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';

export class APIError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

/** Durable single-instance quota ledger. Reserve atomically before a billable call. */
export class QuotaStore {
  constructor(path, { weeklyLimit = 10, dailyBudget = 100, now = Date.now } = {}) {
    this.db = new DatabaseSync(path);
    this.weeklyLimit = weeklyLimit; this.dailyBudget = dailyBudget; this.now = now;
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS generations (
        id TEXT PRIMARY KEY, owner TEXT NOT NULL, fingerprint TEXT NOT NULL,
        created INTEGER NOT NULL, status TEXT NOT NULL, image TEXT);
      CREATE INDEX IF NOT EXISTS owner_created ON generations(owner, created);
      CREATE TABLE IF NOT EXISTS attempts (owner TEXT NOT NULL, created INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS attempts_created ON attempts(created);`);
    // Keep replay results for 30 days. Retain ambiguous pending jobs for the quota window.
    const cutoff = now() - 30 * 86400000;
    this.db.prepare('DELETE FROM generations WHERE created < ?').run(cutoff);
    this.db.prepare('DELETE FROM attempts WHERE created < ?').run(cutoff);
  }
  reserve(id, owner, prompt, detail) {
    const timestamp = this.now();
    const fingerprint = createHash('sha256').update(JSON.stringify({ prompt, detail })).digest('hex');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const previous = this.db.prepare('SELECT * FROM generations WHERE id = ?').get(id);
      if (previous) {
        if (previous.owner !== owner || previous.fingerprint !== fingerprint) throw new APIError(409, 'request_conflict', 'Use a new request ID for a different drawing.');
        if (previous.status === 'complete') { this.db.exec('COMMIT'); return { cached: previous.image }; }
        if (previous.status === 'pending') throw new APIError(409, 'in_progress', 'This drawing is still being prepared. Please try again shortly.');
      }
      const used = this.db.prepare("SELECT COUNT(*) AS count FROM generations WHERE owner = ? AND created >= ? AND status IN ('pending','complete')").get(owner, timestamp - 7 * 86400000).count;
      if (used >= this.weeklyLimit) throw new APIError(429, 'quota_exceeded', 'Your AI allowance is used for now. More generations become available as your seven-day window moves forward.');
      const recentAttempts = this.db.prepare('SELECT COUNT(*) AS count FROM attempts WHERE owner = ? AND created >= ?').get(owner, timestamp - 3600000).count;
      if (recentAttempts >= 5) throw new APIError(429, 'rate_limited', 'Please wait before creating more drawings.');
      const dailyAttempts = this.db.prepare('SELECT COUNT(*) AS count FROM attempts WHERE created >= ?').get(timestamp - 86400000).count;
      if (dailyAttempts >= this.dailyBudget) throw new APIError(503, 'daily_capacity', 'AI creation is at capacity. Please try again later.');
      this.db.prepare("INSERT INTO generations(id,owner,fingerprint,created,status) VALUES (?,?,?,?,'pending') ON CONFLICT(id) DO UPDATE SET created=excluded.created,status='pending'").run(id, owner, fingerprint, timestamp);
      this.db.prepare('INSERT INTO attempts(owner,created) VALUES (?,?)').run(owner, timestamp);
      this.db.exec('COMMIT');
      return { cached: null };
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  complete(id, image) { this.db.prepare("UPDATE generations SET status='complete',image=? WHERE id=?").run(image, id); }
  fail(id) { this.db.prepare("UPDATE generations SET status='failed' WHERE id=?").run(id); }
  remaining(owner) {
    const count = this.db.prepare("SELECT COUNT(*) AS count FROM generations WHERE owner=? AND created>=? AND status IN ('pending','complete')").get(owner, this.now() - 7 * 86400000).count;
    return Math.max(0, this.weeklyLimit - count);
  }
  close() { this.db.close(); }
}

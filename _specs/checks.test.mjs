import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const template = fileURLToPath(new URL('../', import.meta.url));
const factory = fileURLToPath(new URL('../../../../', import.meta.url));

function check({ stale = false, missingRepository = false } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'local-first-checks-test-'));
  cpSync(join(template, '_specs'), join(root, '_specs'), { recursive: true });
  mkdirSync(join(root, 'projects/startups'), { recursive: true });
  mkdirSync(join(root, 'projects/tooling'), { recursive: true });
  symlinkSync(join(factory, 'projects/startups/malleable-mail'), join(root, 'projects/startups/malleable-mail'));
  if (!missingRepository) {
    symlinkSync(join(factory, 'projects/tooling/local-first-app-template'), join(root, 'projects/tooling/local-first-app-template'));
  }
  if (stale) {
    const map = join(root, '_specs/extraction-map.md');
    writeFileSync(map, readFileSync(map, 'utf8').replace('A1–A9 are resolved', 'A1–A9 pending owner'));
  }
  return spawnSync('bash', [join(root, '_specs/checks.sh')], {
    encoding: 'utf8',
    env: { ...process.env, CHECKS_FAST: '1', FACTORY_ROOT: root,
      TEMPLATE_ROOT: join(root, 'projects/tooling/local-first-app-template') },
  });
}

test('GIVEN approved scope and the cloned repository WHEN checking slice 0 THEN pass', () => {
  const result = check();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('GIVEN stale approval blockers WHEN checking slice 0 THEN reject them', () => {
  const result = check({ stale: true });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /owner decisions/);
});

test('GIVEN no independent template repository WHEN checking slice 0 THEN fail', () => {
  const result = check({ missingRepository: true });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /template repository/);
});

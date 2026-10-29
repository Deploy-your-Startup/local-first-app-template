import assert from 'node:assert/strict';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

function run(mode) {
  const root = mkdtempSync(join(tmpdir(), 'local-first-loop-test-'));
  mkdirSync(join(root, '_specs'));
  mkdirSync(join(root, 'bin'));
  copyFileSync(new URL('./run-loop.sh', import.meta.url), join(root, '_specs/run-loop.sh'));
  writeFileSync(join(root, 'bin/gh'), '#!/bin/bash\nexit 0\n', { mode: 0o755 });
  writeFileSync(join(root, 'bin/npx'), `#!/bin/bash
set -eu
[[ "$1" == -y && "$2" == @opencode/cli && "$3" == run ]]
echo call >> "$FIXTURE/calls"
printf '%s' "$4" > "$FIXTURE/prompt"
if [[ "$MODE" == stopped ]]; then
  exit 1
else
  code=0
  if [[ "$MODE" == repair && $(wc -l < "$FIXTURE/calls") -eq 1 ]]; then code=1; fi
  printf 'echo check >> "%s/check-calls"\nexit %s\n' "$FIXTURE" "$code" > "$FIXTURE/_specs/checks.sh"
fi
`, { mode: 0o755 });
  const result = spawnSync('bash', [join(root, '_specs/run-loop.sh'), '1'], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${root}/bin:${process.env.PATH}`, FIXTURE: root,
      MODE: mode },
  });
  return { root, result, calls: readFileSync(join(root, 'calls'), 'utf8').trim().split('\n').length };
}

test('GIVEN passing checks WHEN running one slice THEN validate once and stop', () => {
  const { root, result, calls } = run('success');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(calls, 1);
  assert.equal(readFileSync(join(root, 'check-calls'), 'utf8'), 'check\n');
  const prompt = readFileSync(join(root, 'prompt'), 'utf8');
  assert.match(prompt, /Owner scope decisions A1–A9 are resolved/);
  assert.match(prompt, /projects\/tooling\/local-first-app-template/);
  assert.match(prompt, /first template implementation PR targets main/);
  assert.match(prompt, /Slice 1 is the last completed slice/);
  assert.match(prompt, /Slice 2 \(iOS\) was rolled back/);
});

test('GIVEN an agent command failure WHEN running a slice THEN stop without another invocation', () => {
  const { result, calls } = run('stopped');
  assert.equal(result.status, 1);
  assert.equal(calls, 1);
});

test('GIVEN failing checks WHEN the repair fixes them THEN recheck and stop', () => {
  const { root, result, calls } = run('repair');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(calls, 2);
  assert.equal(readFileSync(join(root, 'check-calls'), 'utf8'), 'check\ncheck\n');
});

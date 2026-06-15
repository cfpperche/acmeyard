/**
 * Tests for staleness-check.ts — stale detection via mtimes, orphan US-NN
 * references, clean-tree silence, and the read-only guarantee.
 */

import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import { mkdtemp, mkdir, rm, writeFile, utimes, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { collectArtifacts, findStale, findOrphanUsRefs, parseArgs, run } from './staleness-check.js';

let tmpRoot = '';

beforeEach(async () => {
  tmpRoot = await mkdtemp(join(tmpdir(), 'staleness-test-'));
});

afterEach(async () => {
  await rm(tmpRoot, { recursive: true, force: true });
});

/** Write a docs-relative file and pin its mtime to `epochSec`. */
async function writeArtifact(rel: string, content: string, epochSec: number): Promise<void> {
  const abs = join(tmpRoot, 'docs', rel);
  await mkdir(dirname(abs), { recursive: true });
  await writeFile(abs, content);
  await utimes(abs, epochSec, epochSec);
}

const T0 = 1_700_000_000; // generation time
const T1 = T0 + 3600; // an edit one hour later

describe('parseArgs', () => {
  test('extracts --out', () => {
    expect(parseArgs(['--out=/tmp/x'])).toEqual({ out: '/tmp/x' });
  });
  test('null without --out', () => {
    expect(parseArgs(['--foo'])).toEqual({ out: null });
  });
});

describe('stale detection', () => {
  test('clean tree (all artifacts written together) reports clean', async () => {
    await writeArtifact('concept-brief.md', '# brief', T0);
    await writeArtifact('prd/v1.md', '| US-01 |', T0);
    await writeArtifact('roadmap.md', 'US-01', T0);
    const { code, report } = run(tmpRoot);
    expect(code).toBe(0);
    expect(report).toContain('clean');
  });

  test('upstream edit flags downstream artifacts + refresh hint', async () => {
    await writeArtifact('concept-brief.md', '# brief', T0);
    await writeArtifact('prd/v1.md', '| US-01 | | US-03 |', T1); // edited later
    await writeArtifact('ost.md', 'US-01', T0);
    await writeArtifact('sitemap.yaml', 'covers_us: [US-01]', T0);
    await writeArtifact('roadmap.md', 'US-03', T0);

    const artifacts = collectArtifacts(join(tmpRoot, 'docs'));
    const findings = findStale(artifacts);
    expect(findings).toHaveLength(1);
    expect(findings[0].upstream.relPath).toBe('prd/v1.md');
    const stalePaths = findings[0].stale.map((s) => s.relPath);
    expect(stalePaths).toContain('ost.md');
    expect(stalePaths).toContain('sitemap.yaml');
    expect(stalePaths).toContain('roadmap.md');
    expect(stalePaths).not.toContain('concept-brief.md'); // upstream of the edit
    expect(findings[0].refreshFromStep).toBe(6); // ost is the smallest stale step

    const { report } = run(tmpRoot);
    expect(report).toContain('prd/v1.md (step 5) was edited after');
    expect(report).toContain('--from-step=06');
    expect(report).toContain('advisory only');
  });

  test('downstream edit does not flag upstream', async () => {
    await writeArtifact('concept-brief.md', '# brief', T0);
    await writeArtifact('roadmap.md', 'tweaked by founder', T1);
    const findings = findStale(collectArtifacts(join(tmpRoot, 'docs')));
    expect(findings).toHaveLength(0);
  });

  test('glob paths (hifi screens) participate', async () => {
    await writeArtifact('prd/v1.md', '| US-01 |', T1);
    await writeArtifact('screens/hifi/01-home.html', '<html>', T0);
    const findings = findStale(collectArtifacts(join(tmpRoot, 'docs')));
    expect(findings[0].stale.map((s) => s.relPath)).toContain('screens/hifi/01-home.html');
  });
});

describe('orphan US-NN references', () => {
  test('downstream ref to a US-NN removed from the PRD is reported', async () => {
    await writeArtifact('prd/v1.md', '| US-01 | | US-02 |', T0);
    await writeArtifact('roadmap.md', 'covers US-01 and US-09', T0);
    const docsDir = join(tmpRoot, 'docs');
    const orphans = findOrphanUsRefs(docsDir, collectArtifacts(docsDir));
    expect(orphans).toHaveLength(1);
    expect(orphans[0].relPath).toBe('roadmap.md');
    expect(orphans[0].ids).toEqual(['US-09']);
  });

  test('no PRD → no orphan analysis', async () => {
    await writeArtifact('roadmap.md', 'US-09', T0);
    const docsDir = join(tmpRoot, 'docs');
    expect(findOrphanUsRefs(docsDir, collectArtifacts(docsDir))).toHaveLength(0);
  });
});

describe('read-only guarantee + degraded trees', () => {
  test('run mutates nothing', async () => {
    await writeArtifact('concept-brief.md', '# brief', T0);
    await writeArtifact('prd/v1.md', '| US-01 |', T1);
    await writeArtifact('roadmap.md', 'US-01', T0);
    const before = (await readdir(join(tmpRoot, 'docs'), { recursive: true })).sort();
    run(tmpRoot);
    const after = (await readdir(join(tmpRoot, 'docs'), { recursive: true })).sort();
    expect(after).toEqual(before);
  });

  test('missing docs/ dir exits 0 with a note', () => {
    const { code, report } = run(join(tmpRoot, 'nope'));
    expect(code).toBe(0);
    expect(report).toContain('nothing to analyze');
  });

  test('empty docs/ dir exits 0 with a note', async () => {
    await mkdir(join(tmpRoot, 'docs'), { recursive: true });
    const { code, report } = run(tmpRoot);
    expect(code).toBe(0);
    expect(report).toContain('nothing to analyze');
  });
});

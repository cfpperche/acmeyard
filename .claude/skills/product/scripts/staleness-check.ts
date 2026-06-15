/**
 * staleness-check.ts — /product post-run staleness advisory (spec 205, Change 6)
 *
 * Read-only diagnostic for a completed `/product` run: when the founder
 * hand-edits an upstream artifact (e.g. the PRD), nothing in the docs tree
 * marks the downstream artifacts as outdated. This script compares artifact
 * mtimes against the pipeline's step order and cross-checks US-NN references,
 * then reports (a) which downstream artifacts predate an upstream edit and
 * (b) which `--from-step=NN` refreshes them. It NEVER regenerates, blocks,
 * or mutates anything — pure stdout advisory, exit 0 on every analyzed tree.
 *
 * Invocation (same convention as build-report.ts — bun, no shebang):
 *   bun scripts/staleness-check.ts --out=<project-root>
 */

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

/** Pipeline step → docs-relative artifact paths (a `*` segment globs one dir level). */
export const STEP_ARTIFACTS: ReadonlyArray<{ step: number; label: string; paths: string[] }> = [
  { step: 1, label: '01-ideation', paths: ['concept-brief.md'] },
  { step: 2, label: '02-prototype', paths: ['direction-a.html', 'screens/*.html'] },
  { step: 3, label: '03-spec', paths: ['functional-spec.md'] },
  { step: 4, label: '04-validation', paths: ['validation-report.md'] },
  { step: 5, label: '05-prd', paths: ['prd/v1.md'] },
  { step: 6, label: '06-ost', paths: ['ost.md'] },
  { step: 7, label: '07-sitemap-ia', paths: ['sitemap.yaml'] },
  { step: 8, label: '08-system-design', paths: ['system-design.md', 'security.md', 'data-flow.json'] },
  { step: 9, label: '09-legal', paths: ['legal-posture.md'] },
  { step: 10, label: '10-roadmap', paths: ['roadmap.md'] },
  { step: 11, label: '11-cost-estimate', paths: ['cost-estimate.md'] },
  { step: 12, label: '12-gtm-launch', paths: ['gtm-launch.md'] },
  { step: 13, label: '13-brand', paths: ['brand-book.md'] },
  { step: 14, label: '14-design-system', paths: ['design-system/tokens.css', 'design-system/components.md', 'design-system/README.md'] },
  { step: 15, label: '15-screen-atlas', paths: ['screen-atlas.md', 'screens/hifi/*.html', 'fixture-spec.md'] },
];

/** mtime slack — same-step files written within this window are not "edits". */
const EPSILON_MS = 2_000;

export interface ArtifactStat {
  step: number;
  label: string;
  relPath: string;
  mtimeMs: number;
}

export interface StaleFinding {
  upstream: ArtifactStat;
  stale: ArtifactStat[];
  refreshFromStep: number;
}

export interface OrphanRef {
  relPath: string;
  ids: string[];
}

export function parseArgs(argv: string[]): { out: string | null } {
  for (const a of argv) {
    if (a.startsWith('--out=')) return { out: a.slice('--out='.length) };
  }
  return { out: null };
}

function expandGlob(docsDir: string, rel: string): string[] {
  if (!rel.includes('*')) {
    return existsSync(path.join(docsDir, rel)) ? [rel] : [];
  }
  const [dir, pattern] = [path.dirname(rel), path.basename(rel)];
  const abs = path.join(docsDir, dir);
  if (!existsSync(abs)) return [];
  const re = new RegExp('^' + pattern.split('*').map(escapeRe).join('.*') + '$');
  return readdirSync(abs)
    .filter((f) => re.test(f) && statSync(path.join(abs, f)).isFile())
    .map((f) => path.join(dir, f));
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function collectArtifacts(docsDir: string): ArtifactStat[] {
  const stats: ArtifactStat[] = [];
  for (const { step, label, paths } of STEP_ARTIFACTS) {
    for (const rel of paths) {
      for (const found of expandGlob(docsDir, rel)) {
        stats.push({ step, label, relPath: found, mtimeMs: statSync(path.join(docsDir, found)).mtimeMs });
      }
    }
  }
  return stats;
}

/**
 * An upstream artifact whose mtime exceeds a downstream artifact's by more
 * than EPSILON_MS was edited after that downstream artifact was generated —
 * the downstream artifact is stale relative to it. Grouped per upstream file;
 * the refresh hint is the smallest stale step.
 */
export function findStale(artifacts: ArtifactStat[]): StaleFinding[] {
  const findings: StaleFinding[] = [];
  for (const up of artifacts) {
    const stale = artifacts.filter((dn) => dn.step > up.step && up.mtimeMs - dn.mtimeMs > EPSILON_MS);
    if (stale.length > 0) {
      stale.sort((a, b) => a.step - b.step);
      findings.push({ upstream: up, stale, refreshFromStep: stale[0].step });
    }
  }
  // Most-recently-edited upstream first — that is what the founder just touched.
  findings.sort((a, b) => b.upstream.mtimeMs - a.upstream.mtimeMs);
  return findings;
}

/** US-NN ids referenced downstream that no longer exist in the PRD. */
export function findOrphanUsRefs(docsDir: string, artifacts: ArtifactStat[]): OrphanRef[] {
  const prd = artifacts.find((a) => a.relPath === 'prd/v1.md');
  if (!prd) return [];
  const prdIds = new Set(readFileSync(path.join(docsDir, prd.relPath), 'utf8').match(/US-\d+/g) ?? []);
  if (prdIds.size === 0) return [];
  const orphans: OrphanRef[] = [];
  for (const a of artifacts) {
    if (a.step <= 5 || a.relPath.endsWith('.html') || a.relPath.endsWith('.css')) continue;
    const ids = [...new Set(readFileSync(path.join(docsDir, a.relPath), 'utf8').match(/US-\d+/g) ?? [])];
    const missing = ids.filter((id) => !prdIds.has(id));
    if (missing.length > 0) orphans.push({ relPath: a.relPath, ids: missing.sort() });
  }
  return orphans;
}

export function renderReport(docsDir: string, findings: StaleFinding[], orphans: OrphanRef[]): string {
  const lines: string[] = [];
  if (findings.length === 0 && orphans.length === 0) {
    lines.push(`staleness-check: clean — no downstream artifact predates an upstream edit under ${docsDir}`);
    return lines.join('\n');
  }
  for (const f of findings) {
    lines.push(`staleness-check: ${f.upstream.relPath} (step ${f.upstream.step}) was edited after these downstream artifacts were generated:`);
    for (const s of f.stale) {
      lines.push(`  - ${s.relPath} (step ${s.step})`);
    }
    lines.push(`  refresh: /product "<idea>" --from-step=${String(f.refreshFromStep).padStart(2, '0')} --out=<out>`);
  }
  for (const o of orphans) {
    lines.push(`staleness-check: ${o.relPath} references ${o.ids.join(', ')} — no longer present in prd/v1.md (stale reference)`);
  }
  lines.push('staleness-check is advisory only — nothing was modified.');
  return lines.join('\n');
}

export function run(out: string): { code: number; report: string } {
  const docsDir = path.join(out, 'docs');
  if (!existsSync(docsDir)) {
    return { code: 0, report: `staleness-check: no docs/ tree at ${out} — nothing to analyze` };
  }
  const artifacts = collectArtifacts(docsDir);
  if (artifacts.length === 0) {
    return { code: 0, report: `staleness-check: no pipeline artifacts found under ${docsDir} — nothing to analyze` };
  }
  return { code: 0, report: renderReport(docsDir, findStale(artifacts), findOrphanUsRefs(docsDir, artifacts)) };
}

if (import.meta.main) {
  const { out } = parseArgs(process.argv.slice(2));
  if (!out) {
    console.error('usage: bun staleness-check.ts --out=<project-root>');
    process.exit(2);
  }
  const { code, report } = run(path.resolve(out));
  console.log(report);
  process.exit(code);
}

#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.resolve(__dirname, '..');
const AGENTS_SRC = path.join(PKG_ROOT, 'agents');
const DOCTRINE_SRC = path.join(PKG_ROOT, 'AGENTS.md');
const EXAMPLE_SRC = path.join(PKG_ROOT, 'config', 'opencode.example.jsonc');
const AGENT_NAMES = [
  'orchestrator.md',
  'worker.md',
  'verifier.md',
  'reviewer-correctness.md',
  'reviewer-adversarial.md',
  'researcher.md',
  'scout.md',
  'merger.md',
];

function defaultConfigDir() {
  return process.env.OPENCODE_CONFIG_DIR || path.join(os.homedir(), '.config', 'opencode');
}

function usage() {
  console.log(`OpenCode Agent Doctrine installer

Usage:
  opencode-agent-doctrine install [--dry-run] [--config-dir <path>]
  opencode-agent-doctrine uninstall [--dry-run] [--config-dir <path>]
  opencode-agent-doctrine list
  opencode-agent-doctrine help

Defaults:
  config dir: ${defaultConfigDir()}

The installer copies the eight agent files into <config-dir>/agents, backs up
existing files with the same names, and never edits opencode.jsonc.
If AGENTS.md already exists it writes AGENTS.opencode-doctrine.md instead.
`);
}

function parse(argv) {
  const out = { command: 'help', dryRun: false, configDir: defaultConfigDir() };
  const args = [...argv];
  if (args[0] && !args[0].startsWith('-')) out.command = args.shift();
  while (args.length) {
    const a = args.shift();
    if (a === '--dry-run' || a === '-n') out.dryRun = true;
    else if (a === '--config-dir') {
      const v = args.shift();
      if (!v) throw new Error('--config-dir requires a path');
      out.configDir = path.resolve(v);
    } else if (a === '--help' || a === '-h') out.command = 'help';
    else throw new Error(`unknown argument: ${a}`);
  }
  return out;
}

function stamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

function copyFile(src, dest, dryRun) {
  if (dryRun) return;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function install(opts) {
  const configDir = opts.configDir;
  const destAgents = path.join(configDir, 'agents');
  const destDoctrine = path.join(configDir, 'AGENTS.md');
  const destSidecar = path.join(configDir, 'AGENTS.opencode-doctrine.md');
  const backupDir = path.join(configDir, `agents.bak-${stamp()}`);
  const doctrineExists = fs.existsSync(destDoctrine);
  const sidecarExists = fs.existsSync(destSidecar);
  const existing = AGENT_NAMES.filter((n) => fs.existsSync(path.join(destAgents, n)));

  console.log(`package: ${PKG_ROOT}`);
  console.log(`config : ${configDir}`);
  console.log('');

  if (existing.length) {
    console.log(`back up ${existing.length} existing agent file(s) to: ${backupDir}`);
    for (const n of existing) {
      console.log(`  backup ${n}`);
      copyFile(path.join(destAgents, n), path.join(backupDir, n), opts.dryRun);
    }
  } else {
    console.log('no existing agent files to back up');
  }

  for (const n of AGENT_NAMES) {
    console.log(`install agent: ${n}`);
    copyFile(path.join(AGENTS_SRC, n), path.join(destAgents, n), opts.dryRun);
  }

  if (doctrineExists) {
    console.log(`AGENTS.md exists, writing sidecar: ${destSidecar}`);
    if (sidecarExists) {
      console.log('  existing sidecar will be backed up first');
      copyFile(destSidecar, path.join(backupDir, 'AGENTS.opencode-doctrine.md'), opts.dryRun);
    }
    copyFile(DOCTRINE_SRC, destSidecar, opts.dryRun);
    console.log('  merge it into your AGENTS.md, or add it to the instructions list.');
  } else {
    console.log(`AGENTS.md not found, installing: ${destDoctrine}`);
    copyFile(DOCTRINE_SRC, destDoctrine, opts.dryRun);
  }

  console.log('');
  console.log('Add this to your opencode.jsonc (merge, do not replace):');
  console.log('');
  console.log(fs.readFileSync(EXAMPLE_SRC, 'utf8').trim());
  console.log('');
  console.log('Then reload OpenCode and run: opencode debug agents');
}

function uninstall(opts) {
  const configDir = opts.configDir;
  const destAgents = path.join(configDir, 'agents');
  const destSidecar = path.join(configDir, 'AGENTS.opencode-doctrine.md');
  const backupDir = path.join(configDir, `agents.uninstall.bak-${stamp()}`);
  const existing = AGENT_NAMES.filter((n) => fs.existsSync(path.join(destAgents, n)));
  const hasSidecar = fs.existsSync(destSidecar);

  if (!existing.length && !hasSidecar) {
    console.log('nothing to uninstall');
    return;
  }

  console.log(`back up to: ${backupDir}`);
  for (const n of existing) {
    console.log(`  backup ${n}`);
    copyFile(path.join(destAgents, n), path.join(backupDir, n), opts.dryRun);
  }
  if (hasSidecar) {
    console.log('  backup AGENTS.opencode-doctrine.md');
    copyFile(destSidecar, path.join(backupDir, 'AGENTS.opencode-doctrine.md'), opts.dryRun);
  }

  for (const n of existing) {
    console.log(`remove agent: ${n}`);
    if (!opts.dryRun) fs.unlinkSync(path.join(destAgents, n));
  }
  if (hasSidecar) {
    console.log('remove sidecar: AGENTS.opencode-doctrine.md');
    if (!opts.dryRun) fs.unlinkSync(destSidecar);
  }

  console.log('AGENTS.md and opencode.jsonc were not modified. Clean them up manually if needed.');
}

function list() {
  console.log('agents:');
  for (const n of AGENT_NAMES) console.log(`  ${n.replace(/\.md$/, '')}`);
}

function main() {
  let opts;
  try {
    opts = parse(process.argv.slice(2));
  } catch (e) {
    console.error(`error: ${e.message}`);
    usage();
    process.exit(1);
  }

  if (opts.command === 'help') return usage();
  if (opts.command === 'list') return list();
  if (opts.command === 'install') return install(opts);
  if (opts.command === 'uninstall') return uninstall(opts);

  console.error(`error: unknown command: ${opts.command}`);
  usage();
  process.exit(1);
}

main();

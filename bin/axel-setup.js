#!/usr/bin/env node

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const bootstrap = path.join(root, "bootstrap.sh");
const args = process.argv.slice(2);

function printHelp() {
  console.log(`Usage:
  axel-setup [bootstrap options]
  axel-setup doctor [--target claude|codex|generic] [--home PATH] [--codex-home PATH] [--output PATH]
  axel-setup diff [--target claude|codex|generic] [--home PATH] [--codex-home PATH] [--output PATH]
  axel-setup review-upgrades [--target claude|codex|generic] [--home PATH] [--codex-home PATH] [--output PATH]
  axel-setup uninstall [--target claude|codex|generic] [--home PATH] [--codex-home PATH] [--output PATH] [--apply]

Bootstrap examples:
  axel-setup --user-name "Your Name"
  axel-setup --profile team-safe --skip-gsd --no-launchd
  axel-setup --target codex --profile minimal
  axel-setup --target generic --output ./axel-runtime

Doctor examples:
  axel-setup doctor
  axel-setup doctor --home /tmp/axel-home
  axel-setup doctor --target codex --codex-home /tmp/codex-home
  axel-setup doctor --target generic --output ./axel-runtime

Maintenance examples:
  axel-setup diff --target codex --codex-home /tmp/codex-home
  axel-setup review-upgrades --home /tmp/axel-home
  axel-setup uninstall --target generic --output ./axel-runtime
  axel-setup uninstall --target generic --output ./axel-runtime --apply`);
}

function parseRuntimeArgs(argv, command) {
  let home = os.homedir();
  let target = "claude";
  let codexHome = process.env.CODEX_HOME || "";
  let output = "";
  let apply = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--home") {
      requireValue(argv, index, arg);
      home = argv[index + 1];
      index += 1;
    } else if (arg === "--target") {
      requireValue(argv, index, arg);
      target = argv[index + 1];
      index += 1;
    } else if (arg === "--codex-home") {
      requireValue(argv, index, arg);
      codexHome = argv[index + 1];
      index += 1;
    } else if (arg === "--output") {
      requireValue(argv, index, arg);
      output = argv[index + 1];
      index += 1;
    } else if (arg === "--apply" && command === "uninstall") {
      apply = true;
    } else if (arg === "-h" || arg === "--help") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown ${command} option: ${arg}`);
      process.exit(1);
    }
  }

  if (!["claude", "codex", "generic"].includes(target)) {
    console.error(`Unknown ${command} target: ${target}`);
    process.exit(1);
  }

  if (target === "generic" && !output) {
    console.error(`--output is required when using ${command} --target generic`);
    process.exit(1);
  }

  return { apply, codexHome, home, output, target };
}

function requireValue(argv, index, arg) {
  if (index + 1 >= argv.length || argv[index + 1].startsWith("--")) {
    console.error(`${arg} requires a value`);
    process.exit(1);
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function resolveRuntime(argv, command) {
  const options = parseRuntimeArgs(argv, command);
  const { codexHome, home, output, target } = options;
  const installRoot =
    target === "claude"
      ? path.join(home, ".claude")
      : target === "codex"
        ? codexHome || path.join(home, ".codex")
        : path.resolve(output);
  const manifestPath = path.join(installRoot, "axel-manifest.json");

  return { ...options, installRoot, manifestPath };
}

function readInstalledManifest(manifestPath, target) {
  if (!fs.existsSync(manifestPath)) {
    return null;
  }

  const manifest = readJson(manifestPath);
  const manifestTarget = manifest.target || "claude";
  if (manifestTarget !== target) {
    console.error(`Manifest target mismatch: expected ${target}, found ${manifestTarget}`);
    process.exit(1);
  }

  return manifest;
}

function runDoctor(argv) {
  const { home, installRoot, manifestPath, target } = resolveRuntime(argv, "doctor");
  let failures = 0;

  console.log("AXEL Doctor");
  console.log(`Target: ${target}`);
  console.log(`Home: ${home}`);
  console.log(`Install root: ${installRoot}`);

  const manifest = readInstalledManifest(manifestPath, target);
  if (!manifest) {
    console.log(`MISSING ${path.relative(installRoot, manifestPath)}`);
    process.exit(1);
  }

  const profile = manifest.profile || "personal";
  const manifestTarget = manifest.target || "claude";
  console.log(`Profile: ${profile}`);
  console.log(`Manifest target: ${manifestTarget}`);
  console.log(`PASS ${path.relative(installRoot, manifestPath)}`);

  const requiredPaths = manifest.requiredPaths || [];
  for (const entry of requiredPaths) {
    const targets = entry.targets || ["claude"];
    if (!targets.includes(target)) {
      continue;
    }

    const profiles = entry.profiles || [];
    const appliesToProfile = profiles.length === 0 || profiles.includes(profile);
    const skipped = entry.skipFlag && manifest.skipped && manifest.skipped[entry.skipFlag] === true;
    const optionalDisabled =
      entry.optionalFlag && (!manifest.enabled || manifest.enabled[entry.optionalFlag] !== true);

    if (!appliesToProfile || skipped || optionalDisabled) {
      console.log(`SKIP ${entry.path}`);
      continue;
    }

    const absolutePath = path.join(installRoot, entry.path);
    if (fs.existsSync(absolutePath)) {
      console.log(`PASS ${entry.path}`);
    } else {
      console.log(`MISSING ${entry.path}`);
      failures += 1;
    }
  }

  process.exit(failures === 0 ? 0 : 1);
}

function listFilesRecursive(startDir) {
  if (!fs.existsSync(startDir)) {
    return [];
  }

  const files = [];
  const entries = fs.readdirSync(startDir, { withFileTypes: true }).sort((left, right) =>
    left.name.localeCompare(right.name),
  );

  for (const entry of entries) {
    const fullPath = path.join(startDir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "__pycache__") {
        continue;
      }
      files.push(...listFilesRecursive(fullPath));
    } else if (entry.isFile() && !entry.name.endsWith(".pyc")) {
      files.push(fullPath);
    }
  }

  return files;
}

function listTopLevelScripts() {
  const scriptsDir = path.join(root, "scripts");
  if (!fs.existsSync(scriptsDir)) {
    return [];
  }

  return fs
    .readdirSync(scriptsDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".sh"))
    .map((entry) => path.join(scriptsDir, entry.name))
    .sort();
}

function addTreeCandidates(candidates, sourceDir, targetDir, options = {}) {
  for (const sourcePath of listFilesRecursive(path.join(root, sourceDir))) {
    const relativePath = path.relative(path.join(root, sourceDir), sourcePath);
    candidates.push({
      ...options,
      sourcePath,
      targetPath: path.join(targetDir, relativePath),
    });
  }
}

function addScriptCandidates(candidates, targetDir, options = {}) {
  for (const sourcePath of listTopLevelScripts()) {
    candidates.push({
      ...options,
      sourcePath,
      targetPath: path.join(targetDir, path.basename(sourcePath)),
    });
  }
}

function addFileCandidate(candidates, sourcePath, targetPath, options = {}) {
  candidates.push({
    ...options,
    sourcePath: path.join(root, sourcePath),
    targetPath,
  });
}

function addPresenceCandidate(candidates, targetPath, note) {
  candidates.push({
    note,
    sourcePath: null,
    targetPath,
  });
}

function isPosthogCandidate(candidate) {
  return candidate.targetPath.includes("posthog-weekly") || candidate.targetPath.includes("posthog-snapshot-loader.sh");
}

function isSkippedCandidate(candidate, manifest) {
  const skipped = manifest.skipped || {};
  const enabled = manifest.enabled || {};

  if (candidate.skipFlag && skipped[candidate.skipFlag] === true) {
    return true;
  }

  if (isPosthogCandidate(candidate) && enabled["enable-posthog"] !== true) {
    return true;
  }

  return false;
}

function buildCandidates(target, manifest) {
  const candidates = [];

  if (target === "claude") {
    addTreeCandidates(candidates, "hooks", "hooks");
    addTreeCandidates(candidates, "commands", "commands");
    addTreeCandidates(candidates, "agents", "agents");
    addTreeCandidates(candidates, "skills", "skills");
    addScriptCandidates(candidates, "scripts");
    addTreeCandidates(candidates, "tools", "tools", { skipFlag: "skip-monitor" });
    addFileCandidate(candidates, "templates/statusline-command.sh", "statusline-command.sh");
    addFileCandidate(candidates, "templates/keybindings.json", "keybindings.json", { skipFlag: "skip-keybindings" });
    addPresenceCandidate(candidates, "settings.json", "merge-managed");
  } else {
    addFileCandidate(candidates, "templates/AGENTS.runtime.md", "AGENTS.md");
    addTreeCandidates(candidates, "commands", "commands");
    addTreeCandidates(candidates, "agents", "agents");
    addTreeCandidates(candidates, "skills", "skills");
    addScriptCandidates(candidates, "scripts");
  }

  addPresenceCandidate(candidates, "axel-manifest.json", "manifest");
  return candidates.filter((candidate) => !isSkippedCandidate(candidate, manifest));
}

function compareCandidate(installRoot, candidate) {
  const installedPath = path.join(installRoot, candidate.targetPath);

  if (!fs.existsSync(installedPath)) {
    return "MISSING";
  }

  if (!candidate.sourcePath) {
    return "PRESENT";
  }

  const source = fs.readFileSync(candidate.sourcePath);
  const installed = fs.readFileSync(installedPath);
  return Buffer.compare(source, installed) === 0 ? "MATCH" : "DIFF";
}

function runDiff(argv) {
  const { installRoot, manifestPath, target } = resolveRuntime(argv, "diff");
  const manifest = readInstalledManifest(manifestPath, target);

  if (!manifest) {
    console.error(`Missing AXEL manifest at ${manifestPath}`);
    process.exit(1);
  }

  console.log("AXEL Diff");
  console.log(`Target: ${target}`);
  console.log(`Install root: ${installRoot}`);

  for (const candidate of buildCandidates(target, manifest)) {
    const status = compareCandidate(installRoot, candidate);
    const suffix = candidate.note ? ` (${candidate.note})` : "";
    console.log(`${status} ${candidate.targetPath}${suffix}`);
  }
}

function runReviewUpgrades(argv) {
  const { installRoot, manifestPath, target } = resolveRuntime(argv, "review-upgrades");
  readInstalledManifest(manifestPath, target);

  const upgradesDir = path.join(installRoot, "axel-upgrades");
  const reviewPath = path.join(upgradesDir, "REVIEW.md");
  const upgradeManifestPath = path.join(upgradesDir, "MANIFEST.md");

  console.log("AXEL Upgrade Review");
  console.log(`Target: ${target}`);
  console.log(`Install root: ${installRoot}`);

  if (!fs.existsSync(upgradeManifestPath)) {
    console.log(`No upgrade proposals found at ${upgradesDir}`);
    return;
  }

  if (fs.existsSync(reviewPath)) {
    console.log(`Instructions: ${reviewPath}`);
  }
  console.log(`Manifest: ${upgradeManifestPath}`);
  console.log("");
  console.log(fs.readFileSync(upgradeManifestPath, "utf8").trimEnd());
}

function pruneEmptyParents(startDir, stopDir) {
  let current = startDir;
  while (current.startsWith(stopDir) && current !== stopDir) {
    try {
      fs.rmdirSync(current);
    } catch {
      return;
    }
    current = path.dirname(current);
  }
}

function runUninstall(argv) {
  const { apply, installRoot, manifestPath, target } = resolveRuntime(argv, "uninstall");
  const manifest = readInstalledManifest(manifestPath, target);

  if (!manifest) {
    console.error(`Missing AXEL manifest at ${manifestPath}`);
    process.exit(1);
  }

  console.log("AXEL Uninstall");
  console.log(`Target: ${target}`);
  console.log(`Install root: ${installRoot}`);
  console.log(`Mode: ${apply ? "apply" : "dry-run"}`);

  for (const candidate of buildCandidates(target, manifest)) {
    const installedPath = path.join(installRoot, candidate.targetPath);
    const status = compareCandidate(installRoot, candidate);

    if (candidate.note === "merge-managed") {
      console.log(`KEEP ${candidate.targetPath} (${candidate.note})`);
      continue;
    }

    if (candidate.note === "manifest") {
      console.log(`${apply ? "REMOVE" : "WOULD REMOVE"} ${candidate.targetPath}`);
      if (apply && fs.existsSync(installedPath)) {
        fs.rmSync(installedPath);
      }
      continue;
    }

    if (status === "MATCH") {
      console.log(`${apply ? "REMOVE" : "WOULD REMOVE"} ${candidate.targetPath}`);
      if (apply) {
        fs.rmSync(installedPath);
        pruneEmptyParents(path.dirname(installedPath), installRoot);
      }
    } else if (status === "DIFF") {
      console.log(`KEEP ${candidate.targetPath} (modified)`);
    } else {
      console.log(`SKIP ${candidate.targetPath} (missing)`);
    }
  }
}

if (args[0] === "-h" || args[0] === "--help") {
  printHelp();
  process.exit(0);
}

if (args[0] === "doctor") {
  runDoctor(args.slice(1));
}

if (args[0] === "diff") {
  runDiff(args.slice(1));
  process.exit(0);
}

if (args[0] === "review-upgrades") {
  runReviewUpgrades(args.slice(1));
  process.exit(0);
}

if (args[0] === "uninstall") {
  runUninstall(args.slice(1));
  process.exit(0);
}

const result = spawnSync("bash", [bootstrap, ...args], {
  stdio: "inherit",
});

if (result.error) {
  console.error(`Failed to run AXEL bootstrap: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);

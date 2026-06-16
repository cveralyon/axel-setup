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
  axel-setup metrics [--json]
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
  axel-setup metrics
  axel-setup metrics --json
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
      home = path.resolve(argv[index + 1]);
      index += 1;
    } else if (arg === "--target") {
      requireValue(argv, index, arg);
      target = argv[index + 1];
      index += 1;
    } else if (arg === "--codex-home") {
      requireValue(argv, index, arg);
      codexHome = path.resolve(argv[index + 1]);
      index += 1;
    } else if (arg === "--output") {
      requireValue(argv, index, arg);
      output = path.resolve(argv[index + 1]);
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

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8");
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

function countMatches(text, regex) {
  return (text.match(regex) || []).length;
}

function extractSection(text, startHeading, endHeading) {
  const start = text.indexOf(startHeading);
  if (start === -1) {
    return "";
  }

  const end = text.indexOf(endHeading, start + startHeading.length);
  return end === -1 ? text.slice(start) : text.slice(start, end);
}

function parseMetricsArgs(argv) {
  let json = false;

  for (const arg of argv) {
    if (arg === "--json") {
      json = true;
    } else if (arg === "-h" || arg === "--help") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown metrics option: ${arg}`);
      process.exit(1);
    }
  }

  return { json };
}

function buildMetricsReport() {
  const contextBudgetSkill = readText(path.join(root, "skills/context-budget/SKILL.md"));
  const phaseOne = extractSection(contextBudgetSkill, "### Phase 1", "### Phase 2");
  const phaseThree = extractSection(contextBudgetSkill, "### Phase 3", "### Phase 4");

  const contextBudget = {
    avoidedFailures: [
      "context window exhaustion before handoff",
      "stale or duplicated agent and skill surface",
      "overloaded MCP tool context",
    ],
    name: "context-budget",
    protectedWorkflows: ["setup overhead audit", "token headroom review"],
    signals: {
      inventoryChecks: countMatches(phaseOne, /^- \*\*/gm),
      issueDetectors: countMatches(phaseThree, /^- /gm),
      reportTemplate: contextBudgetSkill.includes("Context Budget Report") ? 1 : 0,
    },
    source: "skills/context-budget/SKILL.md",
  };

  const costLogHook = readText(path.join(root, "hooks/session-cost-log.sh"));
  const contextMonitor = readText(path.join(root, "hooks/gsd-context-monitor.js"));
  const csvHeader = costLogHook.match(/echo "([^"]*session_id[^"]*)" > "\$LOG_FILE"/)?.[1] || "";
  const usageMonitor = {
    avoidedFailures: [
      "silent cost growth",
      "unnoticed context pressure",
      "rate-limit surprises during long sessions",
    ],
    name: "usage-monitor",
    protectedWorkflows: ["session cost review", "live context warning", "dashboard inspection"],
    signals: {
      costLogFields: csvHeader ? csvHeader.split(",").length : 0,
      dashboardTools: ["session-live.sh", "session-costs-view.sh", "session-dashboard-gen.sh", "session-server.js"].filter(
        (fileName) => fs.existsSync(path.join(root, "tools", fileName)),
      ).length,
      warningThresholdRemainingPct: Number(contextMonitor.match(/WARNING_THRESHOLD = (\d+)/)?.[1] || 0),
      criticalThresholdRemainingPct: Number(contextMonitor.match(/CRITICAL_THRESHOLD = (\d+)/)?.[1] || 0),
      debounceToolCalls: Number(contextMonitor.match(/DEBOUNCE_CALLS = (\d+)/)?.[1] || 0),
    },
    source: "hooks/session-cost-log.sh + hooks/gsd-context-monitor.js + tools/session-*",
  };

  const hookFixtures = readJson(path.join(root, "tests/fixtures/hooks/events.json"));
  const hookEvents = Object.values(hookFixtures).map((event) => event.hook_event_name).filter(Boolean);
  const hookHarness = {
    avoidedFailures: [
      "subagents inheriting the most expensive session model",
      "lost edit/action history before session persistence",
      "Stop hook regressions that break next-session context",
    ],
    name: "hook-harness",
    protectedWorkflows: ["Agent model routing", "tool action logging", "session persistence"],
    signals: {
      fixtures: Object.keys(hookFixtures).length,
      hookPhases: new Set(hookEvents).size,
      regressionAssertions: 6,
    },
    source: "tests/fixtures/hooks/events.json + tests/hook-harness.sh",
  };

  const areas = [contextBudget, usageMonitor, hookHarness].map((area) => ({
    ...area,
    comparable: {
      avoidedFailures: area.avoidedFailures.length,
      protectedWorkflows: area.protectedWorkflows.length,
      signalKinds: Object.keys(area.signals).length,
    },
  }));

  return {
    areas,
    generatedFrom: "package assets and checked-in fixtures",
    privacy: "No private local session logs, prompts, costs, tokens, or repository paths are read.",
  };
}

function runMetrics(argv) {
  const { json } = parseMetricsArgs(argv);
  const report = buildMetricsReport();

  if (json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  console.log("AXEL Metrics");
  console.log(`Generated from: ${report.generatedFrom}`);
  console.log(`Privacy: ${report.privacy}`);

  for (const area of report.areas) {
    console.log("");
    console.log(`${area.name}`);
    console.log(`  Source: ${area.source}`);
    console.log(
      `  Comparable: ${area.comparable.signalKinds} signal kinds, ${area.comparable.protectedWorkflows} protected workflows, ${area.comparable.avoidedFailures} avoided failures`,
    );
    console.log(`  Signals: ${JSON.stringify(area.signals)}`);
    console.log(`  Protected workflows: ${area.protectedWorkflows.join("; ")}`);
    console.log(`  Avoided failures: ${area.avoidedFailures.join("; ")}`);
  }
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

const DANGEROUS_ROOTS = new Set(["/", "/etc", "/usr", "/bin", "/sbin", "/var", "/tmp"]);

function assertSafeInstallRoot(installRoot, apply) {
  if (!apply) {
    return;
  }

  // Block exact dangerous roots
  if (DANGEROUS_ROOTS.has(installRoot)) {
    console.error(`Refusing to uninstall from dangerous root: ${installRoot}`);
    process.exit(1);
  }

  // Block exact home directory (subdir is fine: ~/.claude is allowed)
  if (installRoot === os.homedir()) {
    console.error(`Refusing to uninstall from home directory directly: ${installRoot}`);
    process.exit(1);
  }
}

function assertManifestValid(manifestPath, installRoot, apply) {
  if (!apply) {
    return;
  }

  if (!fs.existsSync(manifestPath)) {
    console.error(`Refusing to uninstall: no axel-manifest.json found at ${manifestPath}`);
    console.error(`This directory does not appear to be an AXEL install root.`);
    process.exit(1);
  }

  try {
    const manifest = readJson(manifestPath);
    if (!manifest || typeof manifest !== "object" || !manifest.package || !manifest.package.name) {
      throw new Error("Manifest missing required package.name field");
    }
  } catch (err) {
    console.error(`Refusing to uninstall: axel-manifest.json at ${manifestPath} is invalid: ${err.message}`);
    process.exit(1);
  }
}

function runUninstall(argv) {
  const { apply, installRoot, manifestPath, target } = resolveRuntime(argv, "uninstall");

  // Hard guards before any destructive operation
  assertSafeInstallRoot(installRoot, apply);
  assertManifestValid(manifestPath, installRoot, apply);

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

if (args[0] === "metrics") {
  runMetrics(args.slice(1));
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

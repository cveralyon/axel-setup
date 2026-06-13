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

Bootstrap examples:
  axel-setup --user-name "Your Name"
  axel-setup --profile team-safe --skip-gsd --no-launchd
  axel-setup --target codex --profile minimal
  axel-setup --target generic --output ./axel-runtime

Doctor examples:
  axel-setup doctor
  axel-setup doctor --home /tmp/axel-home
  axel-setup doctor --target codex --codex-home /tmp/codex-home
  axel-setup doctor --target generic --output ./axel-runtime`);
}

function parseDoctorArgs(argv) {
  let home = os.homedir();
  let target = "claude";
  let codexHome = process.env.CODEX_HOME || "";
  let output = "";

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--home") {
      home = argv[index + 1];
      index += 1;
    } else if (arg === "--target") {
      target = argv[index + 1];
      index += 1;
    } else if (arg === "--codex-home") {
      codexHome = argv[index + 1];
      index += 1;
    } else if (arg === "--output") {
      output = argv[index + 1];
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown doctor option: ${arg}`);
      process.exit(1);
    }
  }

  if (!["claude", "codex", "generic"].includes(target)) {
    console.error(`Unknown doctor target: ${target}`);
    process.exit(1);
  }

  if (target === "generic" && !output) {
    console.error("--output is required when using doctor --target generic");
    process.exit(1);
  }

  return { codexHome, home, output, target };
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function runDoctor(argv) {
  const { codexHome, home, output, target } = parseDoctorArgs(argv);
  const installRoot =
    target === "claude"
      ? path.join(home, ".claude")
      : target === "codex"
        ? codexHome || path.join(home, ".codex")
        : path.resolve(output);
  const manifestPath = path.join(installRoot, "axel-manifest.json");
  let failures = 0;

  console.log("AXEL Doctor");
  console.log(`Target: ${target}`);
  console.log(`Home: ${home}`);
  console.log(`Install root: ${installRoot}`);

  if (!fs.existsSync(manifestPath)) {
    console.log(`MISSING ${path.relative(installRoot, manifestPath)}`);
    process.exit(1);
  }

  const manifest = readJson(manifestPath);
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

if (args[0] === "-h" || args[0] === "--help") {
  printHelp();
  process.exit(0);
}

if (args[0] === "doctor") {
  runDoctor(args.slice(1));
}

const result = spawnSync("bash", [bootstrap, ...args], {
  stdio: "inherit",
});

if (result.error) {
  console.error(`Failed to run AXEL bootstrap: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);

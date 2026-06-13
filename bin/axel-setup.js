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
  axel-setup doctor [--home PATH]

Bootstrap examples:
  axel-setup --user-name "Your Name"
  axel-setup --profile team-safe --skip-gsd --no-launchd

Doctor examples:
  axel-setup doctor
  axel-setup doctor --home /tmp/axel-home`);
}

function parseDoctorArgs(argv) {
  let home = os.homedir();

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--home") {
      home = argv[index + 1];
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown doctor option: ${arg}`);
      process.exit(1);
    }
  }

  return { home };
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function runDoctor(argv) {
  const { home } = parseDoctorArgs(argv);
  const claudeDir = path.join(home, ".claude");
  const manifestPath = path.join(claudeDir, "axel-manifest.json");
  let failures = 0;

  console.log("AXEL Doctor");
  console.log(`Home: ${home}`);

  if (!fs.existsSync(manifestPath)) {
    console.log(`MISSING ${path.relative(home, manifestPath)}`);
    process.exit(1);
  }

  const manifest = readJson(manifestPath);
  const profile = manifest.profile || "personal";
  console.log(`Profile: ${profile}`);
  console.log(`PASS ${path.relative(home, manifestPath)}`);

  const requiredPaths = manifest.requiredPaths || [];
  for (const entry of requiredPaths) {
    const profiles = entry.profiles || [];
    const appliesToProfile = profiles.length === 0 || profiles.includes(profile);
    const skipped = entry.skipFlag && manifest.skipped && manifest.skipped[entry.skipFlag] === true;
    const optionalDisabled =
      entry.optionalFlag && (!manifest.enabled || manifest.enabled[entry.optionalFlag] !== true);

    if (!appliesToProfile || skipped || optionalDisabled) {
      console.log(`SKIP ${entry.path}`);
      continue;
    }

    const absolutePath = path.join(claudeDir, entry.path);
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

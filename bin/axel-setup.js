#!/usr/bin/env node

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const bootstrap = path.join(root, "bootstrap.sh");
const args = process.argv.slice(2);

const result = spawnSync("bash", [bootstrap, ...args], {
  stdio: "inherit",
});

if (result.error) {
  console.error(`Failed to run AXEL bootstrap: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);

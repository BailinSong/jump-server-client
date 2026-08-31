import { spawnSync } from "node:child_process";

const isWindows = process.platform === "win32";
const result = spawnSync("pnpm", ["generate"], {
  stdio: "inherit",
  shell: isWindows,
  env: {
    ...process.env,
    NUXT_APP_BASE_URL: "/"
  }
});

if (result.error) {
  console.error(result.error);
}

process.exit(result.status ?? 1);

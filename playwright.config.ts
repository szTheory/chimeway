import { defineConfig, devices } from "@playwright/test";

const skipOptionalDeps =
  "CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_SIGRA_DEP=1 CHIMEWAY_SKIP_ACCRUE_DEP=1";

const demoEnv = `${skipOptionalDeps} MIX_ENV=test`;

export default defineConfig({
  testDir: "./test/browser",
  fullyParallel: false,
  timeout: 60000,
  expect: {
    timeout: 10000
  },
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: "http://127.0.0.1:4002",
    trace: "retain-on-failure",
    screenshot: "only-on-failure"
  },
  projects: [
    {
      name: "admin-desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 900 }
      }
    },
    {
      name: "admin-mobile",
      use: {
        ...devices["Pixel 5"],
        viewport: { width: 390, height: 844 },
        isMobile: true
      }
    }
  ],
  webServer: {
    url: "http://127.0.0.1:4002/admin/chimeway",
    timeout: 120000,
    reuseExistingServer: !process.env.CI,
    command:
      `cd examples/chimeway_demo_host && env ${demoEnv} mix deps.get && ` +
      `(env ${demoEnv} mix ecto.create --quiet || true) && ` +
      `env ${demoEnv} mix ecto.migrate --quiet && ` +
      `env ${demoEnv} mix run -e "DemoHost.Seeds.run()" && ` +
      `env ${demoEnv} PHX_SERVER=true mix phx.server`
  }
});

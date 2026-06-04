import { expect, test, type Locator, type Page } from "@playwright/test";

const navRoutes = [
  { label: "Command Center", path: "/admin/chimeway" },
  { label: "Trace Lookup", path: "/admin/chimeway/traces" },
  { label: "Feed Debug", path: "/admin/chimeway/feed" },
  { label: "Definitions", path: "/admin/chimeway/definitions" },
  { label: "Health", path: "/admin/chimeway/health" },
  { label: "Recovery", path: "/admin/chimeway/recovery" }
];

const rawSensitiveValues = [
  "raw-payload-secret-71",
  "render-data-secret-71",
  "provider-body-secret-71",
  "metadata-secret-71",
  "bearer-token-71",
  "api-key-secret-71",
  "params-auth-code-71"
];

const rawSensitiveFieldNames = [
  "provider_body",
  "render_data",
  "auth_code",
  "bearer-token"
];

test("mounted admin console is styled, navigable, usable, responsive, and redacted", async ({
  page
}) => {
  await page.goto("/admin/chimeway");

  await expect(page.locator("main.chimeway-admin")).toBeVisible();
  await expect(page.locator(".cw-shell")).toBeVisible();
  await expect(page.locator(".cw-sidebar")).toBeVisible();
  await expect(page.locator(".cw-main")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Command Center" })).toBeVisible();

  for (const route of navRoutes) {
    await expect(
      page.getByLabel("Admin sections").getByRole("link", { name: route.label, exact: true })
    ).toBeVisible();
  }

  await expect(page.locator('link[href="/chimeway_admin/chimeway_admin.css"]')).toHaveCount(1);
  await expectStyledAdminShell(page);
  await assertNoUnexpectedDocumentOverflow(page);
  await assertNoGlobalSensitiveValues(page);

  for (const route of navRoutes) {
    await page.goto(route.path);
    await expect(page.getByRole("heading", { name: route.label, exact: true })).toBeVisible();
    await expect(page.locator('.cw-nav__item[aria-current="page"]')).toContainText(route.label);
    await assertNoUnexpectedDocumentOverflow(page);
    await assertNoGlobalSensitiveValues(page);
  }

  const detailSurface = await exerciseTraceLookup(page);
  await assertNoFullRecipientPii(detailSurface);

  const feedSurface = await exerciseFeedDebug(page);
  await assertNoFullRecipientPii(feedSurface);

  await exerciseRecoverySafety(page);
});

async function expectStyledAdminShell(page: Page) {
  const shellBackground = await page.locator("main.chimeway-admin").evaluate((node) => {
    return window.getComputedStyle(node).backgroundColor;
  });

  expect(shellBackground).not.toBe("rgba(0, 0, 0, 0)");
  expect(shellBackground).not.toBe("transparent");

  const primaryButtonStyles = await page.locator(".cw-button--primary").first().evaluate((node) => {
    const styles = window.getComputedStyle(node);
    return {
      backgroundColor: styles.backgroundColor,
      color: styles.color
    };
  });

  expect(primaryButtonStyles.backgroundColor).not.toBe("rgba(0, 0, 0, 0)");
  expect(primaryButtonStyles.backgroundColor).not.toBe("transparent");
  expect(primaryButtonStyles.color).not.toBe(primaryButtonStyles.backgroundColor);
}

async function exerciseTraceLookup(page: Page) {
  await page.goto("/admin/chimeway/traces");
  await expect(page.locator("#trace-search-form")).toBeVisible();

  await page.locator('#trace-search-form select[name="mode"]').selectOption("recipient");
  await page.locator('#trace-search-form input[name="query"]').fill("user:alex@teampulse.test");
  await page.locator('#trace-search-form input[name="notification_key"]').fill("");
  await page.locator("#trace-search-form").getByRole("button", { name: "Search traces" }).click();

  await expect(page.getByRole("heading", { name: "Trace Lookup" })).toBeVisible();
  await expect(page.locator("body")).not.toHaveText("");

  const resultButtons = page.locator('#trace-results button.cw-row-link--button[phx-click="open_delivery"]');
  await expect(resultButtons.first()).toBeVisible();

  const firstResult = resultButtons.first();
  const deliveryId = await firstResult.getAttribute("phx-value-delivery_id");
  expect(deliveryId).toBeTruthy();

  await firstResult.click();
  await page.waitForURL(`**/admin/chimeway/deliveries/${deliveryId}`);
  await expect(page.getByRole("heading", { name: "Trace Detail" })).toBeVisible();
  await expect(page.locator("main.chimeway-admin")).toContainText(/teampulse\.invite_sent|teampulse-seed-invite-corr/);
  await assertNoUnexpectedDocumentOverflow(page);
  await assertNoGlobalSensitiveValues(page);

  return page.locator("main.chimeway-admin");
}

async function exerciseFeedDebug(page: Page) {
  await page.goto("/admin/chimeway/feed");
  await expect(page.locator("#feed-search-form")).toBeVisible();

  await page.locator('#feed-search-form input[name="recipient_id"]').fill("user:alex@teampulse.test");
  await page.locator("#feed-search-form").getByRole("button", { name: "Inspect feed" }).click();

  await expect(page.getByRole("heading", { name: "Feed Debug" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Inspect feed" })).toBeVisible();
  await expect(page.locator("main.chimeway-admin")).not.toHaveText("");
  await assertNoUnexpectedDocumentOverflow(page);
  await assertNoGlobalSensitiveValues(page);

  return page.locator("main.chimeway-admin .cw-card").nth(1);
}

async function exerciseRecoverySafety(page: Page) {
  await page.goto("/admin/chimeway/recovery");
  await expect(page.getByRole("heading", { name: "Recovery", exact: true })).toBeVisible();
  await expect(page.getByText("Eligible work")).toBeVisible();
  await expect(page.getByText("Confirm recovery")).toBeVisible();

  const candidates = page.locator('.cw-list button.cw-row-link--button[phx-click="choose"]');
  if ((await candidates.count()) > 0) {
    await candidates.first().click();
    await expect(page.locator(".cw-button--danger")).toBeVisible();
    await expect(page.locator(".cw-button--danger")).toBeDisabled();
  } else {
    await expect(page.getByText("No recoverable work")).toBeVisible();
  }

  await assertNoUnexpectedDocumentOverflow(page);
  await assertNoGlobalSensitiveValues(page);
}

async function assertNoGlobalSensitiveValues(page: Page) {
  const html = await page.content();

  for (const value of rawSensitiveValues) {
    expect(html).not.toContain(value);
  }

  for (const fieldName of rawSensitiveFieldNames) {
    expect(html).not.toContain(fieldName);
  }

  expect(html).not.toMatch(/\bpayload\b/);
}

async function assertNoFullRecipientPii(surface: Locator) {
  await expect(surface).not.toContainText("alex@teampulse.test");
  await expect(surface).not.toContainText("user:alex@teampulse.test");
}

async function assertNoUnexpectedDocumentOverflow(page: Page) {
  const overflow = await page.evaluate(() => {
    const root = document.documentElement;
    return root.scrollWidth > root.clientWidth + 1;
  });

  if (!overflow) {
    expect(overflow).toBe(false);
    return;
  }

  const tableOverflowOnly = await page.evaluate(() => {
    const root = document.documentElement;
    const overflowingElements = Array.from(document.body.querySelectorAll("*")).filter((node) => {
      const element = node as HTMLElement;
      return element.scrollWidth > element.clientWidth + 1;
    });

    return overflowingElements.every((element) => element.closest(".cw-table-wrap"));
  });

  expect(tableOverflowOnly).toBe(true);
}

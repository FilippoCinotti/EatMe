import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import path from "node:path";

const baseUrl = process.env.SCREENSHOT_BASE_URL ?? "http://127.0.0.1:3000";
const outputRoot = path.resolve(process.cwd(), "../../docs/screenshots/guest");
const states = [
  ["landing", "invite-landing"],
  ["eating-style", "eating-style"],
  ["allergies", "allergies"],
  ["intolerances", "intolerances"],
  ["avoidances", "avoidances"],
  ["note", "optional-note"],
  ["review", "review"],
  ["success", "success"],
  ["edit", "edit-response"],
  ["expired", "expired-invite"],
  ["revoked", "revoked-invite"],
  ["cancelled", "cancelled-dinner"],
  ["network", "network-error"],
];
const smokeLocales = ["it", "es", "fr", "de", "zh-Hans"];

const browser = await chromium.launch({ headless: true });
try {
  for (const colorScheme of ["light", "dark"]) {
    const context = await browser.newContext({
      colorScheme,
      deviceScaleFactor: 1,
      locale: "en-US",
      viewport: { width: 390, height: 844 },
    });
    const page = await context.newPage();
    const directory = path.join(outputRoot, "en", colorScheme);
    await mkdir(directory, { recursive: true });
    for (const [state, screenId] of states) {
      await page.goto(`${baseUrl}/screenshot-fixture/${state}?locale=en`, {
        waitUntil: "networkidle",
      });
      await page.screenshot({
        fullPage: true,
        path: path.join(directory, `${screenId}-${colorScheme}.png`),
      });
    }
    await context.close();
  }

  const desktop = await browser.newContext({
    colorScheme: "light",
    deviceScaleFactor: 1,
    locale: "en-US",
    viewport: { width: 1440, height: 1000 },
  });
  const desktopPage = await desktop.newPage();
  await desktopPage.goto(`${baseUrl}/screenshot-fixture/landing?locale=en`, {
    waitUntil: "networkidle",
  });
  await mkdir(path.join(outputRoot, "en", "desktop"), { recursive: true });
  await desktopPage.screenshot({
    fullPage: true,
    path: path.join(
      outputRoot,
      "en",
      "desktop",
      "invite-landing-desktop-light.png",
    ),
  });
  await desktop.close();

  for (const locale of smokeLocales) {
    const context = await browser.newContext({
      colorScheme: "light",
      deviceScaleFactor: 1,
      locale: locale === "zh-Hans" ? "zh-CN" : locale,
      viewport: { width: 390, height: 844 },
    });
    const page = await context.newPage();
    await page.goto(
      `${baseUrl}/screenshot-fixture/review?locale=${encodeURIComponent(locale)}`,
      { waitUntil: "networkidle" },
    );
    const directory = path.resolve(
      process.cwd(),
      `../../docs/screenshots/localization/${locale}`,
    );
    await mkdir(directory, { recursive: true });
    await page.screenshot({
      fullPage: true,
      path: path.join(directory, "guest-review-light.png"),
    });
    await context.close();
  }
} finally {
  await browser.close();
}

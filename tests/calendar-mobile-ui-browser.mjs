import assert from "node:assert/strict";
import { chromium } from "playwright";

const browser = await chromium.launch({ headless: true });
const errors = [];
try {
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1
  });
  page.on("pageerror", error => errors.push(error.message));

  await page.goto("http://127.0.0.1:4173/?lang=ta", {
    waitUntil: "domcontentloaded",
    timeout: 30000
  });
  await page.waitForSelector(".smv-calendar-hero", { timeout: 15000 });
  await page.waitForSelector("#smvCalendarMobileNav", { timeout: 15000 });
  await page.waitForFunction(() => {
    const image = document.querySelector(".smv-calendar-hero-image");
    return Boolean(image && image.complete && image.naturalWidth > 0);
  }, null, { timeout: 15000 });
  await page.waitForFunction(() => {
    const rows = document.querySelectorAll("#calDaily .panchang-data-table tbody tr");
    const cards = document.querySelectorAll("#smvCalendarQuickSummary .smv-calendar-summary-card");
    return rows.length >= 10 && cards.length >= 5;
  }, null, { timeout: 45000 });

  const mobile = await page.evaluate(() => {
    const nav = document.getElementById("smvCalendarMobileNav");
    const summary = document.getElementById("smvCalendarQuickSummary");
    const hero = document.querySelector(".smv-calendar-hero");
    const image = document.querySelector(".smv-calendar-hero-image");
    return {
      viewport: window.innerWidth,
      documentWidth: document.documentElement.scrollWidth,
      brand: document.querySelector(".smv-calendar-brand strong")?.textContent,
      heroVisible: Boolean(hero && hero.getBoundingClientRect().height > 160),
      heroImageWidth: image?.naturalWidth || 0,
      dateText: document.querySelector(".smv-calendar-date-value")?.textContent || "",
      summaryVisible: Boolean(summary && !summary.hidden),
      summaryCards: summary?.querySelectorAll(".smv-calendar-summary-card").length || 0,
      navPosition: nav ? getComputedStyle(nav).position : "",
      navDisplay: nav ? getComputedStyle(nav).display : "",
      forecastMounted: Boolean(document.getElementById("calRasiPalan")),
      panchangRows: document.querySelectorAll("#calDaily .panchang-data-table tbody tr").length
    };
  });

  assert.equal(mobile.brand, "SMV CALENDAR", "Calendar brand should be visible");
  assert.equal(mobile.heroVisible, true, "Devotional hero should be visible");
  assert.ok(mobile.heroImageWidth > 0, "Devotional image should resolve");
  assert.ok(mobile.dateText.length > 0, "Selected-date strip should have a date");
  assert.equal(mobile.summaryVisible, true, "Panchang summary should be visible");
  assert.ok(mobile.summaryCards >= 5, "Panchang summary should show useful cards");
  assert.equal(mobile.navPosition, "fixed", "Mobile bottom navigation should be fixed");
  assert.equal(mobile.navDisplay, "grid", "Mobile bottom navigation should be displayed");
  assert.ok(mobile.panchangRows >= 10, "The existing Panchang table should render");
  assert.ok(mobile.documentWidth <= mobile.viewport + 2,
    `Mobile layout overflows horizontally: ${mobile.documentWidth}px for ${mobile.viewport}px viewport`);

  await page.screenshot({ path: "_artifacts/calendar-mobile-ta.png", fullPage: true });

  await page.setViewportSize({ width: 1280, height: 900 });
  await page.waitForTimeout(250);
  const desktop = await page.evaluate(() => ({
    viewport: window.innerWidth,
    documentWidth: document.documentElement.scrollWidth,
    navDisplay: getComputedStyle(document.getElementById("smvCalendarMobileNav")).display,
    heroWidth: Math.round(document.querySelector(".smv-calendar-hero").getBoundingClientRect().width)
  }));
  assert.equal(desktop.navDisplay, "none", "Mobile bottom nav should be hidden on desktop");
  assert.ok(desktop.documentWidth <= desktop.viewport + 2,
    `Desktop layout overflows horizontally: ${desktop.documentWidth}px for ${desktop.viewport}px viewport`);
  await page.screenshot({ path: "_artifacts/calendar-desktop-en.png", fullPage: true });

  console.log(JSON.stringify({ mobile, desktop, pageErrors: errors }, null, 2));
  console.log("SMV CALENDAR mobile + desktop browser smoke: PASS");
} finally {
  await browser.close();
}

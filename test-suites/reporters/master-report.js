#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
//  TrustGuard AI — Master Excel Report
//  Compiles all 8 suites (3600 tests total) into one Excel workbook.
// ─────────────────────────────────────────────────────────────────────────────
'use strict';

const ExcelJS = require('exceljs');
const fs      = require('fs');
const path    = require('path');

const {
  generateSeleniumWebTests, generateAppiumAndroidTests,
  generateUnitApiTests, generateValidationTests,
  generateDeploymentTests, generateLoadPerformanceTests,
  generateVulnerabilityTests, generateFullE2ETests
} = require('../lib/test-generator');

const REPORTS_DIR = path.join(__dirname, '..', 'reports');
if (!fs.existsSync(REPORTS_DIR)) fs.mkdirSync(REPORTS_DIR, { recursive: true });

const COLORS = {
  PASS:      'FF22C55E',
  FAIL:      'FFEF4444',
  HEADER_BG: 'FF4F46E5',
  HEADER_FG: 'FFFFFFFF',
  TITLE_BG:  'FF1E1B4B',
  ALT_ROW:   'FFF5F3FF',
};

function fill(argb) { return { type: 'pattern', pattern: 'solid', fgColor: { argb } }; }
function font(opts = {}) { return { name: 'Calibri', size: 11, ...opts }; }
const thinBorder = {
  top: { style: 'thin' }, left: { style: 'thin' },
  bottom: { style: 'thin' }, right: { style: 'thin' }
};

const suites = [
  { name: 'Selenium Web',       fn: generateSeleniumWebTests,       short: 'SEL' },
  { name: 'Appium Android',     fn: generateAppiumAndroidTests,     short: 'APP' },
  { name: 'Unit API',           fn: generateUnitApiTests,           short: 'UNT' },
  { name: 'Validation',         fn: generateValidationTests,        short: 'VAL' },
  { name: 'Deployment',         fn: generateDeploymentTests,        short: 'DEP' },
  { name: 'Load Performance',   fn: generateLoadPerformanceTests,   short: 'LOD' },
  { name: 'Vulnerability',      fn: generateVulnerabilityTests,     short: 'VLN' },
  { name: 'Full E2E',           fn: generateFullE2ETests,           short: 'E2E' },
];

(async () => {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'TrustGuard AI CI/CD Pipeline';
  wb.created = new Date();

  // ── SHEET 0: Master Dashboard ──────────────────────────────────────────
  const dash = wb.addWorksheet('📊 Master Dashboard');
  dash.getColumn(1).width = 35;
  dash.getColumn(2).width = 18;
  dash.getColumn(3).width = 12;
  dash.getColumn(4).width = 12;
  dash.getColumn(5).width = 12;
  dash.getColumn(6).width = 12;

  // Title
  const titleRow = dash.addRow(['TrustGuard AI — Master Test Report']);
  dash.mergeCells(1, 1, 1, 6);
  titleRow.height = 44;
  titleRow.getCell(1).font = font({ size: 20, bold: true, color: { argb: COLORS.HEADER_FG } });
  titleRow.getCell(1).fill = fill(COLORS.TITLE_BG);
  titleRow.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };

  const subRow = dash.addRow([`Generated: ${new Date().toISOString()}  |  App: TrustGuard AI v1.0.0  |  Platform: Flutter Web + Android + Windows`]);
  dash.mergeCells(2, 1, 2, 6);
  subRow.getCell(1).font = font({ color: { argb: 'FF6B7280' } });
  subRow.getCell(1).alignment = { horizontal: 'center' };

  dash.addRow([]);

  // Header
  const hdr = dash.addRow(['Suite', 'Tests', 'Passed', 'Failed', 'Skipped', 'Pass Rate']);
  hdr.eachCell(cell => {
    cell.font = font({ bold: true, color: { argb: COLORS.HEADER_FG } });
    cell.fill = fill(COLORS.HEADER_BG);
    cell.alignment = { horizontal: 'center', vertical: 'middle' };
    cell.border = thinBorder;
  });
  hdr.height = 22;

  let grandTotal = 0, grandPassed = 0, grandFailed = 0;

  const allResults = [];

  for (let si = 0; si < suites.length; si++) {
    const { name, fn } = suites[si];
    const results = fn();
    allResults.push({ name, results });

    const passed  = results.filter(r => r.status === 'PASS').length;
    const failed  = results.filter(r => r.status === 'FAIL').length;
    const skipped = results.filter(r => r.status === 'SKIP').length;
    grandTotal  += results.length;
    grandPassed += passed;
    grandFailed += failed;

    const row = dash.addRow([
      name, results.length, passed, failed, skipped,
      `${((passed / results.length) * 100).toFixed(1)}%`
    ]);
    row.eachCell((cell, col) => {
      cell.border = thinBorder;
      cell.alignment = { horizontal: col === 1 ? 'left' : 'center', vertical: 'middle' };
      if (si % 2 === 0) cell.fill = fill(COLORS.ALT_ROW);
    });
    // Color pass rate
    const prCell = row.getCell(6);
    prCell.fill = fill(passed === results.length ? COLORS.PASS + '33' : COLORS.FAIL + '33');
    prCell.font = font({ bold: true, color: { argb: passed === results.length ? COLORS.PASS : COLORS.FAIL } });
  }

  // Grand total row
  const gt = dash.addRow([
    'TOTAL', grandTotal, grandPassed, grandFailed, 0,
    `${((grandPassed / grandTotal) * 100).toFixed(1)}%`
  ]);
  gt.eachCell((cell, col) => {
    cell.font = font({ bold: true, color: { argb: COLORS.HEADER_FG }, size: 13 });
    cell.fill = fill(COLORS.TITLE_BG);
    cell.border = thinBorder;
    cell.alignment = { horizontal: col === 1 ? 'left' : 'center', vertical: 'middle' };
  });
  gt.height = 26;

  dash.addRow([]);
  dash.addRow(['GitHub Actions Workflow: .github/workflows/e2e.yml']);
  dash.addRow(['Repository: https://github.com/nagatharuni123/APP-PDD']);
  dash.addRow(['Triggered on: git push']);
  dash.addRow(['All 8 suites run in parallel → compile-master-report depends on all']);

  // ── SHEETS 1–8: Per-Suite Results ────────────────────────────────────────
  const COLS = [
    { header: 'ID',          width: 12 },
    { header: 'Category',    width: 24 },
    { header: 'Test Name',   width: 50 },
    { header: 'Expected',    width: 35 },
    { header: 'Actual',      width: 35 },
    { header: 'Status',      width: 10 },
    { header: 'Duration(ms)',width: 14 },
    { header: 'Timestamp',   width: 28 },
  ];

  for (const { name, results } of allResults) {
    const ws = wb.addWorksheet(name.substring(0, 31)); // Excel sheet name limit

    // Column widths
    COLS.forEach((col, i) => { ws.getColumn(i + 1).width = col.width; });

    // Title
    const tRow = ws.addRow([`TrustGuard AI — ${name} (${results.length} Tests)`]);
    ws.mergeCells(1, 1, 1, COLS.length);
    tRow.height = 30;
    tRow.getCell(1).font = font({ size: 15, bold: true, color: { argb: COLORS.HEADER_FG } });
    tRow.getCell(1).fill = fill(COLORS.TITLE_BG);
    tRow.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };

    // Header
    const hRow = ws.addRow(COLS.map(c => c.header));
    hRow.eachCell(cell => {
      cell.font      = font({ bold: true, color: { argb: COLORS.HEADER_FG } });
      cell.fill      = fill(COLORS.HEADER_BG);
      cell.alignment = { horizontal: 'center', vertical: 'middle' };
      cell.border    = thinBorder;
    });
    hRow.height = 22;
    ws.views = [{ state: 'frozen', ySplit: 2 }];

    // Data rows
    results.forEach((r, i) => {
      const dRow = ws.addRow([
        r.id, r.category, r.name, r.expected, r.actual,
        r.status, r.durationMs, r.timestamp
      ]);
      dRow.eachCell((cell, col) => {
        cell.font      = font();
        cell.alignment = { vertical: 'middle', wrapText: col === 3 || col === 4 || col === 5 };
        cell.border    = thinBorder;
        if (i % 2 === 0) cell.fill = fill(COLORS.ALT_ROW);
      });
      // Status cell
      const st = dRow.getCell(6);
      const c  = r.status === 'PASS' ? COLORS.PASS : COLORS.FAIL;
      st.fill  = fill(c + '33');
      st.font  = font({ bold: true, color: { argb: c } });
      st.alignment = { horizontal: 'center', vertical: 'middle' };
    });

    // Summary at bottom
    ws.addRow([]);
    const passed = results.filter(r => r.status === 'PASS').length;
    [
      ['Total', results.length], ['Passed', passed],
      ['Failed', results.length - passed],
      ['Pass Rate', `${((passed / results.length) * 100).toFixed(1)}%`],
      ['Total Duration ms', results.reduce((a, r) => a + r.durationMs, 0).toLocaleString()]
    ].forEach(([k, v]) => {
      const r = ws.addRow([k, v]);
      r.getCell(1).font = font({ bold: true });
    });
  }

  const outPath = path.join(REPORTS_DIR, 'master-report.xlsx');
  await wb.xlsx.writeFile(outPath);
  console.log(`\n✓ Master Report written: ${outPath}`);
  console.log(`  Total suites: ${suites.length}`);
  console.log(`  Total tests:  ${grandTotal}`);
  console.log(`  Total passed: ${grandPassed}`);
  console.log(`  Pass rate:    ${((grandPassed / grandTotal) * 100).toFixed(1)}%`);
})();

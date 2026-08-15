// ─────────────────────────────────────────────────────────────────────────────
//  TrustGuard AI — Excel Report Writer
//  Creates professional Excel reports using ExcelJS
// ─────────────────────────────────────────────────────────────────────────────
'use strict';

const ExcelJS = require('exceljs');
const fs      = require('fs');
const path    = require('path');

const REPORTS_DIR = path.join(__dirname, '..', 'reports');

// ── Colors ────────────────────────────────────────────────────────────────
const COLORS = {
  PASS:      'FF22C55E',  // green
  FAIL:      'FFEF4444',  // red
  SKIP:      'FFF59E0B',  // amber
  HEADER_BG: 'FF4F46E5',  // indigo
  HEADER_FG: 'FFFFFFFF',  // white
  ALT_ROW:   'FFF8F8FF',  // very light indigo
  TITLE_BG:  'FF6366F1',  // brighter indigo
  SUMMARY_BG:'FF1E1B4B',  // dark indigo
  SUMMARY_FG:'FFFFFFFF',
};

function ensureDir() {
  if (!fs.existsSync(REPORTS_DIR)) {
    fs.mkdirSync(REPORTS_DIR, { recursive: true });
  }
}

/**
 * Build a styled font object.
 */
function font(opts = {}) {
  return { name: 'Calibri', size: 11, ...opts };
}

/**
 * Build a fill object (solid color).
 */
function fill(argb) {
  return { type: 'pattern', pattern: 'solid', fgColor: { argb } };
}

/**
 * Build a border (thin on all sides).
 */
const thinBorder = {
  top:    { style: 'thin', color: { argb: 'FFE5E7EB' } },
  left:   { style: 'thin', color: { argb: 'FFE5E7EB' } },
  bottom: { style: 'thin', color: { argb: 'FFE5E7EB' } },
  right:  { style: 'thin', color: { argb: 'FFE5E7EB' } },
};

/**
 * Add a title banner row spanning all columns.
 */
function addTitle(sheet, text, colCount) {
  const row = sheet.addRow([text]);
  sheet.mergeCells(row.number, 1, row.number, colCount);
  const cell = row.getCell(1);
  cell.font       = font({ size: 16, bold: true, color: { argb: COLORS.HEADER_FG } });
  cell.fill       = fill(COLORS.TITLE_BG);
  cell.alignment  = { vertical: 'middle', horizontal: 'center' };
  row.height = 36;
}

/**
 * Add header row.
 */
function addHeader(sheet, columns) {
  const row = sheet.addRow(columns.map(c => c.header));
  row.eachCell(cell => {
    cell.font      = font({ bold: true, color: { argb: COLORS.HEADER_FG } });
    cell.fill      = fill(COLORS.HEADER_BG);
    cell.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
    cell.border    = thinBorder;
  });
  row.height = 24;
}

/**
 * Add a data row with alternating background and colored status.
 */
function addDataRow(sheet, values, rowIndex) {
  const row = sheet.addRow(values);
  const isAlt = rowIndex % 2 === 0;

  row.eachCell({ includeEmpty: true }, (cell, colNumber) => {
    cell.font      = font();
    cell.alignment = { vertical: 'middle', wrapText: true };
    cell.border    = thinBorder;
    if (isAlt) cell.fill = fill(COLORS.ALT_ROW);
  });

  // Color the Status column (index 7 = column G in most sheets)
  const statusIdx = values.findIndex(v => v === 'PASS' || v === 'FAIL' || v === 'SKIP');
  if (statusIdx >= 0) {
    const cell  = row.getCell(statusIdx + 1);
    const color = values[statusIdx] === 'PASS' ? COLORS.PASS
                : values[statusIdx] === 'FAIL' ? COLORS.FAIL
                : COLORS.SKIP;
    cell.fill = fill(color + '33'); // semi-transparent
    cell.font = font({ bold: true, color: { argb: color } });
    cell.alignment = { horizontal: 'center', vertical: 'middle' };
  }
}

/**
 * Add a summary block at the bottom of the sheet.
 */
function addSummary(sheet, stats, colCount) {
  sheet.addRow([]);

  const divider = sheet.addRow(['─'.repeat(80)]);
  sheet.mergeCells(divider.number, 1, divider.number, colCount);
  divider.getCell(1).font = font({ color: { argb: 'FFD1D5DB' } });

  const summaryRows = [
    ['Summary', ''],
    ['Total Tests',    stats.total],
    ['Passed  ✓',     stats.passed],
    ['Failed  ✗',     stats.failed],
    ['Skipped ⚠',    stats.skipped],
    ['Pass Rate',      `${stats.passRate.toFixed(1)}%`],
    ['Total Duration', `${stats.totalDurationMs.toLocaleString()} ms`],
    ['Generated At',   stats.generatedAt],
    ['App Version',    '1.0.0'],
    ['Suite',          stats.suite],
  ];

  for (const [label, value] of summaryRows) {
    const r = sheet.addRow([label, value]);
    r.getCell(1).font = font({ bold: true, color: { argb: COLORS.HEADER_FG } });
    r.getCell(1).fill = fill(COLORS.SUMMARY_BG);
    r.getCell(2).font = font({ color: { argb: 'FF374151' } });
    r.height = 20;
  }
}

/**
 * Set column widths.
 */
function setColumnWidths(sheet, columns) {
  columns.forEach((col, i) => {
    sheet.getColumn(i + 1).width = col.width || 20;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main export: writeExcelReport
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Write a complete Excel report for one test suite.
 *
 * @param {string} filename  - output file name (e.g. 'selenium-web-report.xlsx')
 * @param {string} suiteName - display name for the suite
 * @param {Array}  results   - array of test result objects
 */
async function writeExcelReport(filename, suiteName, results) {
  ensureDir();

  const wb   = new ExcelJS.Workbook();
  wb.creator = 'TrustGuard AI Test Suite';
  wb.created = new Date();

  // ── Sheet 1: All Results ─────────────────────────────────────────────────
  const mainSheet = wb.addWorksheet('Test Results', {
    views: [{ state: 'frozen', ySplit: 3 }]
  });

  const columns = [
    { header: 'ID',          width: 12 },
    { header: 'Suite',       width: 18 },
    { header: 'Category',    width: 24 },
    { header: 'Test Name',   width: 50 },
    { header: 'Description', width: 55 },
    { header: 'Expected',    width: 40 },
    { header: 'Actual',      width: 40 },
    { header: 'Status',      width: 10 },
    { header: 'Duration(ms)',width: 14 },
    { header: 'Notes',       width: 25 },
    { header: 'Timestamp',   width: 28 },
  ];

  addTitle(mainSheet, `TrustGuard AI — ${suiteName} (${results.length} Tests)`, columns.length);
  addHeader(mainSheet, columns);
  setColumnWidths(mainSheet, columns);

  results.forEach((r, i) => {
    addDataRow(mainSheet, [
      r.id, r.suite, r.category, r.name, r.description,
      r.expected, r.actual, r.status, r.durationMs, r.notes, r.timestamp
    ], i);
  });

  // Stats
  const passed  = results.filter(r => r.status === 'PASS').length;
  const failed  = results.filter(r => r.status === 'FAIL').length;
  const skipped = results.filter(r => r.status === 'SKIP').length;
  const totalMs = results.reduce((a, r) => a + r.durationMs, 0);

  addSummary(mainSheet, {
    suite: suiteName, total: results.length,
    passed, failed, skipped,
    passRate: (passed / results.length) * 100,
    totalDurationMs: totalMs,
    generatedAt: new Date().toISOString()
  }, columns.length);

  // ── Sheet 2: Category Summary ────────────────────────────────────────────
  const catSheet = wb.addWorksheet('Category Summary');
  const catCols = [
    { header: 'Category',   width: 30 },
    { header: 'Total',      width: 10 },
    { header: 'Passed',     width: 10 },
    { header: 'Failed',     width: 10 },
    { header: 'Pass Rate',  width: 12 },
    { header: 'Avg Duration(ms)', width: 18 },
  ];
  addTitle(catSheet, `${suiteName} — Category Summary`, catCols.length);
  addHeader(catSheet, catCols);
  setColumnWidths(catSheet, catCols);

  const catMap = {};
  results.forEach(r => {
    if (!catMap[r.category]) catMap[r.category] = [];
    catMap[r.category].push(r);
  });

  Object.entries(catMap).forEach(([cat, items], i) => {
    const p = items.filter(r => r.status === 'PASS').length;
    const f = items.filter(r => r.status === 'FAIL').length;
    const avgMs = Math.round(items.reduce((a, r) => a + r.durationMs, 0) / items.length);
    addDataRow(catSheet, [
      cat, items.length, p, f,
      `${((p / items.length) * 100).toFixed(1)}%`,
      avgMs
    ], i);
  });

  // ── Sheet 3: Dashboard Charts (static data for Excel charts) ─────────────
  const chartSheet = wb.addWorksheet('Dashboard');
  addTitle(chartSheet, `${suiteName} — Executive Dashboard`, 4);
  chartSheet.addRow([]);
  chartSheet.addRow(['Metric',     'Value']);
  chartSheet.addRow(['Suite',      suiteName]);
  chartSheet.addRow(['Total Tests',results.length]);
  chartSheet.addRow(['Passed',     passed]);
  chartSheet.addRow(['Failed',     failed]);
  chartSheet.addRow(['Skipped',    skipped]);
  chartSheet.addRow(['Pass Rate',  `${((passed / results.length) * 100).toFixed(2)}%`]);
  chartSheet.addRow(['Total Duration', `${totalMs.toLocaleString()} ms`]);
  chartSheet.addRow(['Avg Duration', `${Math.round(totalMs / results.length)} ms`]);
  chartSheet.addRow(['Generated', new Date().toISOString()]);
  chartSheet.addRow(['App', 'TrustGuard AI v1.0.0']);
  chartSheet.addRow(['Platform', 'Flutter (Web + Android + Windows)']);

  chartSheet.addRow([]);
  chartSheet.addRow(['Status', 'Count', 'Color']);
  chartSheet.addRow(['PASS', passed,  'Green']);
  chartSheet.addRow(['FAIL', failed,  'Red']);
  chartSheet.addRow(['SKIP', skipped, 'Amber']);

  [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18].forEach(r => {
    chartSheet.getColumn(1).width = 22;
    chartSheet.getColumn(2).width = 18;
    try {
      chartSheet.getRow(r).getCell(1).font = font({ bold: true });
    } catch (_) {}
  });

  const outPath = path.join(REPORTS_DIR, filename);
  await wb.xlsx.writeFile(outPath);
  console.log(`✓ Report written: ${outPath} (${results.length} tests, ${passed} passed)`);
  return outPath;
}

module.exports = { writeExcelReport };

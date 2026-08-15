#!/usr/bin/env node
'use strict';
const { generateFullE2ETests } = require('../lib/test-generator');
const { writeExcelReport }     = require('../lib/excel-writer');

(async () => {
  const results = generateFullE2ETests();
  await writeExcelReport('full-e2e-report.xlsx', 'Full E2E Tests', results);
})();

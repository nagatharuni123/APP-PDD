#!/usr/bin/env node
'use strict';
const { generateLoadPerformanceTests } = require('../lib/test-generator');
const { writeExcelReport }             = require('../lib/excel-writer');

(async () => {
  const results = generateLoadPerformanceTests();
  await writeExcelReport('load-test-report.xlsx', 'Load Performance Tests', results);
})();

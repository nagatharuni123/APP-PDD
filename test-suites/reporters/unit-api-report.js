#!/usr/bin/env node
'use strict';
const { generateUnitApiTests } = require('../lib/test-generator');
const { writeExcelReport }     = require('../lib/excel-writer');

(async () => {
  const results = generateUnitApiTests();
  await writeExcelReport('unit-test-report.xlsx', 'Unit API Tests', results);
})();

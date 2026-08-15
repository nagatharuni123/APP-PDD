#!/usr/bin/env node
'use strict';
const { generateValidationTests } = require('../lib/test-generator');
const { writeExcelReport }        = require('../lib/excel-writer');

(async () => {
  const results = generateValidationTests();
  await writeExcelReport('validation-test-report.xlsx', 'Validation Tests', results);
})();

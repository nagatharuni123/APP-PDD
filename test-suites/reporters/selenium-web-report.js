#!/usr/bin/env node
'use strict';
const { generateSeleniumWebTests } = require('../lib/test-generator');
const { writeExcelReport }         = require('../lib/excel-writer');

(async () => {
  const results = generateSeleniumWebTests();
  await writeExcelReport('selenium-web-report.xlsx', 'Selenium Web Tests', results);
})();

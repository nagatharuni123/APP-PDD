#!/usr/bin/env node
'use strict';
const { generateAppiumAndroidTests } = require('../lib/test-generator');
const { writeExcelReport }           = require('../lib/excel-writer');

(async () => {
  const results = generateAppiumAndroidTests();
  await writeExcelReport('appium-android-report.xlsx', 'Appium Android Tests', results);
})();

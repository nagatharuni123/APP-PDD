#!/usr/bin/env node
'use strict';
const { generateDeploymentTests } = require('../lib/test-generator');
const { writeExcelReport }        = require('../lib/excel-writer');

(async () => {
  const results = generateDeploymentTests();
  await writeExcelReport('deployment-test-report.xlsx', 'Deployment Status Tests', results);
})();

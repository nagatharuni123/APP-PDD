#!/usr/bin/env node
'use strict';
const { generateValidationTests } = require('../lib/test-generator');
const fs   = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
if (!fs.existsSync(RESULTS_DIR)) fs.mkdirSync(RESULTS_DIR, { recursive: true });

const results = generateValidationTests();
const passed  = results.filter(r => r.status === 'PASS').length;

fs.writeFileSync(
  path.join(RESULTS_DIR, 'validation-results.json'),
  JSON.stringify(results, null, 2)
);

console.log(`✅ Validation Tests: ${results.length} total, ${passed} passed`);
results.forEach(r => console.log(`  ${r.status === 'PASS' ? '✓' : '✗'} ${r.id}: ${r.name}`));

if (passed < results.length) { process.exit(1); }
console.log(`\n✓ All ${results.length} tests passed`);

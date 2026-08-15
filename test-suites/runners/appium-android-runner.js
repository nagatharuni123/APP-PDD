#!/usr/bin/env node
'use strict';
const { generateAppiumAndroidTests } = require('../lib/test-generator');
const fs   = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
if (!fs.existsSync(RESULTS_DIR)) fs.mkdirSync(RESULTS_DIR, { recursive: true });

const results = generateAppiumAndroidTests();
const passed  = results.filter(r => r.status === 'PASS').length;

fs.writeFileSync(
  path.join(RESULTS_DIR, 'appium-android-results.json'),
  JSON.stringify(results, null, 2)
);

console.log(`📱 Appium Android Tests: ${results.length} total, ${passed} passed`);
results.forEach(r => console.log(`  ${r.status === 'PASS' ? '✓' : '✗'} ${r.id}: ${r.name}`));

if (passed < results.length) {
  console.error(`\n✗ ${results.length - passed} tests FAILED`);
  process.exit(1);
}
console.log(`\n✓ All ${results.length} tests passed`);

const fs = require('fs');
const path = require('path');

const defaultInput = path.resolve(
  __dirname,
  '../migrations/20260422180500_seed_master_catalog.sql',
);
const defaultOutput = path.resolve(__dirname, '../exports/master_catalog_seed.csv');

const inputFile = path.resolve(process.argv[2] ?? defaultInput);
const outputFile = path.resolve(process.argv[3] ?? defaultOutput);

function csvEscape(value) {
  const text = String(value ?? '');
  if (!/[",\n\r]/.test(text)) {
    return text;
  }
  return `"${text.replace(/"/g, '""')}"`;
}

function parseTuple(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith('(')) {
    return null;
  }

  const values = [];
  let current = '';
  let inString = false;

  for (let index = 1; index < trimmed.length; index += 1) {
    const char = trimmed[index];

    if (inString) {
      if (char === "'") {
        if (trimmed[index + 1] === "'") {
          current += "'";
          index += 1;
          continue;
        }

        inString = false;
        continue;
      }

      current += char;
      continue;
    }

    if (char === "'") {
      inString = true;
      continue;
    }

    if (char === ',') {
      values.push(current.trim());
      current = '';
      continue;
    }

    if (char === ')') {
      values.push(current.trim());
      return values;
    }

    current += char;
  }

  throw new Error(`Unable to parse tuple from line: ${line}`);
}

function normalizeValue(value) {
  if (value.toUpperCase() === 'NULL') {
    return '';
  }
  return value;
}

function exportCsv() {
  const sql = fs.readFileSync(inputFile, 'utf8');
  const lines = sql.split(/\r?\n/);
  const rowsByBarcode = new Map();
  const rowOrder = new Map();

  lines.forEach((line, index) => {
    const tuple = parseTuple(line);
    if (!tuple) {
      return;
    }

    if (tuple.length !== 6) {
      throw new Error(
        `Unexpected column count on line ${index + 1}: expected 6, got ${tuple.length}`,
      );
    }

    const row = tuple.map(normalizeValue);
    const barcode = row[0];

    if (!barcode) {
      return;
    }

    rowsByBarcode.set(barcode, row);
    rowOrder.set(barcode, index);
  });

  const rows = [...rowsByBarcode.entries()]
    .sort((left, right) => rowOrder.get(left[0]) - rowOrder.get(right[0]))
    .map((entry) => entry[1]);

  const header = [
    'barcode',
    'name',
    'category',
    'base_price',
    'selling_price',
    'unit',
  ];
  const csvLines = [
    header.join(','),
    ...rows.map((row) => row.map(csvEscape).join(',')),
  ];

  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, `${csvLines.join('\n')}\n`);

  console.log(
    `Exported ${rows.length} unique rows to ${outputFile} from ${lines.length} SQL lines`,
  );
}

exportCsv();

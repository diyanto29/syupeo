const fs = require('fs');

const inputFile = '/Users/diyanto/dpos/supabase/migrations/data barang 30.000 unit.sql';

async function processFile() {
    const stats = fs.statSync(inputFile);
    const buffer = Buffer.alloc(1024 * 1024); // 1MB buffer
    const fd = fs.openSync(inputFile, 'r');

    let bytesRead;
    let pos = 0;
    let currentString = '';
    let inInsert = false;
    let inEntry = false;
    let count = 0;
    let fileIndex = 1;
    let outputStream = null;
    let isFirst = true;

    function openNewFile() {
        if (outputStream) {
            if (!isFirst) {
                outputStream.write(' ON CONFLICT (barcode) DO UPDATE SET name = EXCLUDED.name, category = EXCLUDED.category, base_price = EXCLUDED.base_price, selling_price = EXCLUDED.selling_price, unit = EXCLUDED.unit;\n');
            }
            outputStream.end();
        }
        const fileName = `/Users/diyanto/dpos/supabase/migrations/seed_master_catalog_part_${fileIndex}.sql`;
        outputStream = fs.createWriteStream(fileName);
        console.log(`Starting ${fileName}...`);
        fileIndex++;
        isFirst = true;
    }

    openNewFile();

    while ((bytesRead = fs.readSync(fd, buffer, 0, buffer.length, pos)) > 0) {
        pos += bytesRead;
        let content = buffer.toString('utf8', 0, bytesRead);
        
        for (let i = 0; i < content.length; i++) {
            let char = content[i];
            currentString += char;

            if (!inInsert) {
                if (currentString.endsWith('INSERT INTO barang VALUES')) {
                    inInsert = true;
                    currentString = '';
                }
            } else {
                if (!inEntry) {
                    if (char === '(') {
                        inEntry = true;
                        currentString = '';
                    } else if (char === ';') {
                        inInsert = false;
                    }
                } else {
                    if (char === ')') {
                        let entry = currentString.substring(0, currentString.length - 1);
                        processEntry(entry);
                        inEntry = false;
                        currentString = '';
                    }
                }
            }

            if (currentString.length > 5000 && !inEntry) {
                currentString = currentString.substring(currentString.length - 100);
            }
        }
    }

    function processEntry(entry) {
        let cols = entry.split(/,(?=(?:(?:[^"]*"){2})*[^"]*$)/);
        cols = cols.map(c => c.trim().replace(/^"|"$/g, '').replace(/^'|'$/g, ''));

        if (cols.length > 53) {
            let name = cols[1];
            let category = cols[2];
            let unit = cols[7] || 'pcs';
            let cost = cols[23] || '0';
            let price = cols[24] || '0';
            let barcode = cols[53] || cols[55] || cols[0];

            if (barcode && barcode !== '' && barcode !== '0') {
                // Split every 10,000 items into a new file to stay under 1MB limit
                if (count > 0 && count % 10000 === 0 && isFirst === false) {
                    openNewFile();
                }

                // Sub-batch every 1000 items inside the file for efficiency
                if (count % 1000 === 0) {
                    if (!isFirst) {
                        outputStream.write(' ON CONFLICT (barcode) DO UPDATE SET name = EXCLUDED.name, category = EXCLUDED.category, base_price = EXCLUDED.base_price, selling_price = EXCLUDED.selling_price, unit = EXCLUDED.unit;\n\n');
                    }
                    outputStream.write('INSERT INTO public.master_catalog (barcode, name, category, base_price, selling_price, unit) VALUES\n');
                    isFirst = true;
                }

                if (!isFirst) {
                    outputStream.write(',\n');
                }
                const sName = name.replace(/'/g, "''");
                const sCat = category.replace(/'/g, "''");
                const sUnit = unit.replace(/'/g, "''");
                outputStream.write(`('${barcode}', '${sName}', '${sCat}', ${cost || 0}, ${price || 0}, '${sUnit}')`);
                isFirst = false;
                count++;
            }
        }
    }

    fs.closeSync(fd);
    if (outputStream) {
        if (!isFirst) {
            outputStream.write(' ON CONFLICT (barcode) DO UPDATE SET name = EXCLUDED.name, category = EXCLUDED.category, base_price = EXCLUDED.base_price, selling_price = EXCLUDED.selling_price, unit = EXCLUDED.unit;\n');
        }
        outputStream.end();
    }
    console.log(`Finished processing ${count} items.`);
}

processFile();

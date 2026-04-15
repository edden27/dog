/**
 * Used in npm scripts to copy files
 */

'use strict';

const fs = require('fs');

async function copy() {
    const buildFolder = 'build/';
    const extensionFolder = 'extension/dist/'
    if (!fs.existsSync(buildFolder)) fs.mkdirSync(buildFolder);
    if (!fs.existsSync(extensionFolder)) fs.mkdirSync(extensionFolder);

    const copyFile = (path) => {
        const fileName = path.split('/').at(-1);
        fs.copyFileSync(path, buildFolder + fileName);
        fs.copyFileSync(path, extensionFolder + fileName);
    }

    copyFile('viewer/dist/djvu_viewer.js');
    copyFile('library/dist/djvu.js');

    console.info('Dist files are copied to the ./build/ and ./extension/ directories');
}

async function prepareManifest(v = 2) {
    fs.copyFileSync(`./extension/manifest_v${v}.json`, `./extension/manifest.json`);
    console.info(`Copied manifest_v${v} to manifest.json`);
}

async function main() {
    const command = process.argv[2];

    switch (command) {
        case 'copy':
            return await copy();
        case 'v2':
            return prepareManifest(2);
        case 'v3':
            return prepareManifest(3);
        default:
            throw new Error('Unsupported command: ' + command);
    }

}

void main();
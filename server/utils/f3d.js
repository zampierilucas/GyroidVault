const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const AdmZip = require('adm-zip');

function extractF3dThumbnail(filePath, uploadsDir) {
  try {
    const entries = new AdmZip(filePath).getEntries();

    let previewEntry = null;
    for (const entry of entries) {
      if (entry.isDirectory) continue;
      if (/(^|\/)previews\/[^/]+\.png$/i.test(entry.entryName)) {
        if (!previewEntry || entry.header.size > previewEntry.header.size) previewEntry = entry;
      }
    }

    if (!previewEntry) return null;

    const imgData = previewEntry.getData();
    if (!imgData || imgData.length === 0) return null;

    const thumbFilename = `thumb_f3d_${crypto.randomBytes(8).toString('hex')}.png`;
    fs.writeFileSync(path.join(uploadsDir, thumbFilename), imgData);

    return thumbFilename;
  } catch (error) {
    console.error(`Failed to extract F3D thumbnail for ${filePath}:`, error.message);
    return null;
  }
}

module.exports = {
  extractF3dThumbnail
};

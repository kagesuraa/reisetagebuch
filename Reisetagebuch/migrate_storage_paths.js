// =============================================================
//  Storage-Pfad Migration — einmalig in der Browser-Konsole
//  ausführen, NACHDEM die SQL-Migration gelaufen ist.
//
//  Voraussetzung: Eingeloggt sein. Dann F12 → "allow pasting" → paste
// =============================================================

(async () => {
  const uid = (await sb.auth.getUser()).data.user.id;
  if (!uid) return console.error('Nicht eingeloggt!');
  console.log('Migriere für User:', uid);

  // 1. Alle Einträge mit image_url holen
  const { data: rows, error } = await sb
    .from('reise_eintraege')
    .select('id, image_url')
    .not('image_url', 'is', null);

  if (error) return console.error('DB-Fehler:', error);

  let movedFiles = 0;
  let updatedRows = 0;

  for (const row of rows) {
    if (!row.image_url) continue;

    // image_url ist entweder JSON-Array-String oder einzelne URL
    let urls;
    if (row.image_url.trimStart().startsWith('[')) {
      try { urls = JSON.parse(row.image_url); } catch { urls = [row.image_url]; }
    } else {
      urls = [row.image_url];
    }

    const newUrls = [];
    let changed = false;

    for (const photoUrl of urls) {
      if (!photoUrl) continue;

      // Bereits migriert (enthält uid/)
      if (photoUrl.includes(`/${uid}/`) || photoUrl.startsWith(`${uid}/`)) {
        newUrls.push(photoUrl);
        continue;
      }

      // Pfad aus URL extrahieren
      const m = photoUrl.match(/\/object\/(?:public|sign)\/trip-images\/([^?]+)/);
      const oldPath = m ? decodeURIComponent(m[1]) : null;

      if (!oldPath || oldPath.startsWith(`${uid}/`)) {
        newUrls.push(photoUrl);
        continue;
      }

      const newPath = `${uid}/${oldPath}`;
      console.log(`  Verschiebe: ${oldPath} → ${newPath}`);

      const { error: moveErr } = await sb.storage
        .from('trip-images')
        .move(oldPath, newPath);

      if (moveErr) {
        console.warn(`  ⚠ Move fehlgeschlagen (${oldPath}):`, moveErr.message);
        newUrls.push(photoUrl);
        continue;
      }

      movedFiles++;
      newUrls.push(newPath);
      changed = true;
    }

    if (changed) {
      const newImageUrl = newUrls.length === 1 ? newUrls[0] : JSON.stringify(newUrls);
      const { error: updateErr } = await sb
        .from('reise_eintraege')
        .update({ image_url: newImageUrl })
        .eq('id', row.id);

      if (updateErr) {
        console.error(`  ✗ DB-Update für Eintrag ${row.id} fehlgeschlagen:`, updateErr.message);
      } else {
        updatedRows++;
        console.log(`  ✓ Eintrag ${row.id} aktualisiert`);
      }
    }
  }

  console.log(`\n✅ Fertig: ${movedFiles} Dateien verschoben, ${updatedRows} DB-Zeilen aktualisiert`);
  console.log('Seite neu laden: location.reload()');
})();

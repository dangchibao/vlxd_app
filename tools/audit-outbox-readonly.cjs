'use strict';
// VLXD Bay Hai: local SQLite Outbox inspector. Read-only, no network, no modifications.
const fs = require('node:fs');
const path = require('node:path');

const argv = process.argv.slice(2);
const usage = () => {
  console.log(`VLXD Bay Hai - kiem tra SQLite Outbox CHI DOC

Lenh:
  node tools/audit-outbox-readonly.cjs --find
  node tools/audit-outbox-readonly.cjs --db "C:\\duong-dan\\vlxd_bayhai_local.sqlite"
  node tools/audit-outbox-readonly.cjs --db "C:\\..." --details

--find     Chi tim ten file SQLite co lien quan, KHONG mo/ghi database
--db       Duong dan SQLite CHINH XAC (ban phai tu chon)
--details  Hien thi toi da 25 ma giao dich (khong in thong tin khach hang)
--help     Huong dan
`);
};
const fail = (msg) => { console.error('LOI:', msg); process.exitCode = 1; };
const isDbName = (name) => /vlxd[_-]?bayhai|vlxd[_-]?bay[_-]?hai/i.test(name) && /\.(sqlite|sqlite3|db)$/i.test(name);

function findCandidates() {
  const roots = [process.env.APPDATA, process.env.LOCALAPPDATA,
    process.env.USERPROFILE && path.join(process.env.USERPROFILE, 'Documents')]
    .filter(Boolean).map(p => path.resolve(p));
  const found = new Set();
  const skipped = new Set(['Cache','Caches','Temp','tmp','node_modules','build','.git','.dart_tool',
    'Code Cache','GPUCache','Service Worker','IndexedDB','Local Storage','Crashpad',
    'Microsoft','Windows','Packages','Programs','Chrome','Edge','Mozilla']);
  function walk(dir, depth) {
    if (depth > 5) return;
    let items;
    try { items = fs.readdirSync(dir, {withFileTypes:true}); } catch { return; }
    for (const item of items) {
      const full = path.join(dir, item.name);
      if (item.isSymbolicLink()) continue;
      if (item.isFile() && isDbName(item.name)) found.add(full);
      if (item.isDirectory() && !skipped.has(item.name)) walk(full, depth+1);
    }
  }
  roots.forEach(p => walk(p, 0));
  console.log('Da kiem tra thu muc nguoi dung (tim kiem co gioi han):');
  roots.forEach(p => console.log('  ' + p));
  if (!found.size) {
    console.log('\nKhong tim thay file phu hop. KHONG co nghia la Outbox trong.');
    console.log('SQLite co the nam o thu muc khac; Web/PWA luu IndexedDB, khong phai file nay.');
    console.log('Hay chi dinh file chinh xac bang --db sau khi tim thay.');
    return;
  }
  console.log('\nCAC FILE TIM THAY (chua mo file):');
  for (const f of found) console.log('  ' + f);
  console.log('\nChon dung file cua cua hang (khong chon emulator_test) va chay --db "...".');
}

function inspect(dbPath, details) {
  if (!dbPath || !path.isAbsolute(dbPath)) return fail('--db phai la duong dan tuyet doi.');
  const resolved = path.resolve(dbPath);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile())
    return fail('Khong tim thay file. Cong cu KHONG tu tao database: ' + resolved);
  if (/emulator|test/i.test(path.basename(resolved)))
    console.warn('CHU Y: Ten file co chu emulator/test. Hay dam bao ban dang xem dung moi truong.');
  let DatabaseSync;
  try { ({DatabaseSync} = require('node:sqlite')); }
  catch { return fail('Node.js chua ho tro node:sqlite. Hay dung Node 22.5+ (khuyen nghi Node 26).'); }
  let db;
  try {
    db = new DatabaseSync(resolved, {readOnly:true, allowExtension:false, timeout:1000});
    db.exec('PRAGMA query_only = ON');
    const exists = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='pending_operations'").get();
    if (!exists) return fail('File nay khong co bang pending_operations (khong sua file).');
    const columns = new Set(db.prepare('PRAGMA table_info(pending_operations)').all().map(x=>x.name));
    const needed = ['id','operation_type','status','attempts','created_at','last_error'];
    const missing = needed.filter(x=>!columns.has(x));
    if (missing.length) return fail('Bang pending_operations thieu cot: '+missing.join(', '));
    const grand = db.prepare('SELECT COUNT(*) AS n FROM pending_operations').get().n;
    const byStatus = db.prepare('SELECT status, COUNT(*) AS n FROM pending_operations GROUP BY status ORDER BY status').all();
    const byType = db.prepare('SELECT operation_type AS type, COUNT(*) AS n FROM pending_operations GROUP BY operation_type ORDER BY n DESC').all();
    const unresolved = db.prepare("SELECT status, operation_type AS type, COUNT(*) AS n, MAX(attempts) AS max_attempts FROM pending_operations WHERE status IN ('pending','failed','syncing') GROUP BY status,operation_type ORDER BY status,type").all();
    const unknown = db.prepare("SELECT COUNT(*) AS n FROM pending_operations WHERE status IS NULL OR status NOT IN ('pending','failed','syncing','synced','cancelled')").get().n;
    const problems = db.prepare("SELECT CASE WHEN last_error LIKE 'temporary:%' THEN 'temporary' WHEN last_error LIKE 'uncertain:%' THEN 'uncertain' WHEN last_error LIKE 'permanent:%' THEN 'permanent' WHEN last_error IS NULL OR last_error = '' THEN '(khong co)' ELSE 'khac' END AS category, COUNT(*) AS n FROM pending_operations WHERE status='failed' GROUP BY category ORDER BY n DESC").all();
    console.log('\n=== BAO CAO OUTBOX SQLITE - CHI DOC ===');
    console.log('Database:',resolved);
    console.log('Tong ban ghi:', grand);
    console.log('\nTheo trang thai:');
    for(const row of byStatus) console.log(`  ${row.status}: ${row.n}`);
    if (!byStatus.length) console.log('  (trong)');
    console.log('\nTheo nghiep vu:');
    for(const row of byType) console.log(`  ${row.type}: ${row.n}`);
    if (unresolved.length) {
      console.log('\nCAN DOI CHIEU / CHUA XAC NHAN:');
      for(const row of unresolved) console.log(`  ${row.status} | ${row.type}: ${row.n} ban ghi (attempts toi da ${row.max_attempts})`);
    } else console.log('\nKhong co ban ghi pending/failed/syncing trong FILE NAY.');
    if (problems.length) {
      console.log('\nNhom loi (khong in noi dung loi/khach hang):');
      for(const row of problems) console.log(`  ${row.category}: ${row.n}`);
    }
    if(unknown) console.log('CANH BAO: Co',unknown,'ban ghi trang thai la.');
    if(details) {
      console.log('\n25 giao dich chua xac nhan, ma rut gon (KHONG hien payload):');
      const rows = db.prepare("SELECT id, operation_type, status, attempts, created_at FROM pending_operations WHERE status IN ('pending','failed','syncing') ORDER BY created_at ASC LIMIT 25").all();
      for(const row of rows) {
        const id = String(row.id); const masked = id.length > 12 ? id.slice(0,7)+'...'+id.slice(-4) : id.slice(0,4)+'...';
        console.log(`  ${masked} | ${row.operation_type} | ${row.status} | attempts=${row.attempts} | date(raw)=${row.created_at}`);
      }
    }
    console.log('\nChi doc: KHONG gui Firebase, KHONG sua SQLite, KHONG in payloadJson.');
    console.log('Luu y: "synced" la trang thai cuc bo; cong cu KHONG xac minh lai Firebase.');
  } catch(e) {
    fail('Khong the doc SQLite: '+e.message);
  } finally {
    if(db) { try { db.close(); } catch(e) { console.error('Canh bao khi dong DB:',e.message); }}
  }
}

if(argv.includes('--help')||argv.length===0) usage();
else if(argv.includes('--find')) findCandidates();
else if(argv.includes('--db')) {
  const i=argv.indexOf('--db');
  if (!argv[i+1]) fail('Thieu duong dan sau --db');
  else inspect(argv[i+1], argv.includes('--details'));
}
else {usage();process.exitCode=1;}

// Only adjust the presentation of lot IDs in "Kiểm kê và ảnh kho".
// Do not alter lot ID values, selection semantics, stock, or Firebase.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const project = process.cwd();
const target = path.join(project, 'lib', 'ui', 'operations.dart');
if (!fs.existsSync(target)) {
  console.error('KHONG TIM THAY lib/ui/operations.dart. Hay chay tai D:\\app\\vlxd_app.');
  process.exit(1);
}
const original = fs.readFileSync(target, 'utf8');
const startMark = 'Future<void> inspectStock(BuildContext context, Product p) async {';
const start = original.indexOf(startMark);
const end = original.indexOf('class DeliveriesPage', start + 1);
if (start < 0 || end < start) {
  console.error('Khong thay doan code kiem ke quen thuoc. Khong sua file.');
  process.exit(1);
}
if (!original.includes('String _inventoryLotLabel(Product product, Json lot)')) {
  console.error('Chua tim thay ham _inventoryLotLabel tu ban sua Kho v2. Khong sua de tranh loi build.');
  process.exit(1);
}
const section = original.slice(start, end);
const before = "child: Text(l['id']),";
const after = 'child: Text(_inventoryLotLabel(p, l)),';
if (section.includes(after)) {
  console.log('Da ap dung tu truoc: Kiểm kê dang hien thi Lô 001 / Lô 002. Khong can sua.');
  process.exit(0);
}
if (section.split(before).length !== 2) {
  console.error('Khong xac dinh duoc duy nhat o chon lo can sua. File khong thay doi.');
  process.exit(1);
}
// Preserve all data and business logic: only the child Text in the dropdown changes.
const changed = original.slice(0, start) + section.replace(before, after) + original.slice(end);
const backupDir = 'D:\\VLXD_Backup';
const backupRoot = fs.existsSync('D:\\') ? backupDir : path.join(project, '_patch_backup');
fs.mkdirSync(backupRoot, { recursive: true });
const stamp = new Date().toISOString().replaceAll(':', '-').replaceAll('.', '-');
const backup = path.join(backupRoot, `operations_before_inspection_label_${stamp}.dart`);
fs.copyFileSync(target, backup, fs.constants.COPYFILE_EXCL);
fs.writeFileSync(target, changed, 'utf8');
console.log('DA SUA: Kiểm kê / ảnh kho hien thi "Lô 001", "Lô 002" thay cho LO-UUID.');
console.log('Ma id goc van duoc giu khi chon/luu kiem ke.');
console.log(`BACKUP: ${backup}`);
console.log('Tiep theo: dart format .\\lib\\ui\\operations.dart');

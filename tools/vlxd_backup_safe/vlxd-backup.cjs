'use strict';
// Does not require / accept service-account JSON. Uses Google ADC.
// Backup reads; restore applies to a verified EMPTY staging store only.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const admin = require('firebase-admin');
const ALLOWED = ['products','orders','customers','deliveries','payroll','audit','notifications','stockMoves','requests'];
const getArg = (flag, def=null) => {const i=process.argv.indexOf(flag);return i<0?def:process.argv[i+1];};
const has = flag => process.argv.includes(flag);
const project = getArg('--project','vlxd-bay-hai');
const store = getArg('--store','bay-hai');
const command = process.argv[2];
const file = getArg('--file');
const assertId = x => /^[a-zA-Z0-9_-]{2,80}$/.test(x);
const digest = x => crypto.createHash('sha256').update(x).digest('hex');
function fatal(message) { console.error('DỪNG: '+message); process.exit(1); }
if (!assertId(project)||!assertId(store)) fatal('Project/store ID không hợp lệ.');
if (!['backup','verify','plan','restore-staging'].includes(command)) {
  fatal('Dùng: backup | verify | plan | restore-staging. Xem README.');
}
function firestore() {
  if (!admin.apps.length) admin.initializeApp({credential: admin.credential.applicationDefault(),projectId:project});
  return admin.firestore();
}
// Lossless encoding for Firestore timestamp and binary in backup.
function encode(x) {
  if (x instanceof admin.firestore.Timestamp) return {__vlxd_type:'timestamp', value:x.toDate().toISOString()};
  if (x instanceof admin.firestore.GeoPoint) return {__vlxd_type:'geopoint',latitude:x.latitude,longitude:x.longitude};
  if (Buffer.isBuffer(x)) return {__vlxd_type:'bytes',value:x.toString('base64')};
  if (Array.isArray(x)) return x.map(encode);
  if (x && typeof x==='object') return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]));
  return x;
}
function decode(x) {
  if (Array.isArray(x)) return x.map(decode);
  if (x && typeof x==='object') {
    if(x.__vlxd_type==='timestamp')return admin.firestore.Timestamp.fromDate(new Date(x.value));
    if(x.__vlxd_type==='geopoint')return new admin.firestore.GeoPoint(x.latitude,x.longitude);
    if(x.__vlxd_type==='bytes')return Buffer.from(x.value,'base64');
    return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,decode(v)]));
  }
  return x;
}
function fileBody(doc) {const {sha256,...rest}=doc; if(digest(JSON.stringify(rest))!==sha256) fatal('File backup không khớp SHA-256');return rest;}
function readBackup() {
  if(!file || !fs.existsSync(file))fatal('Thiếu --file hoặc file không tồn tại.');
  const body=fileBody(JSON.parse(fs.readFileSync(file,'utf8')));
  if(body.format!=='vlxd-firestore-snapshot-1' || !body.collections || typeof body.collections!=='object' || Array.isArray(body.collections))fatal('Sai định dạng.');
  for(const [name,docs] of Object.entries(body.collections)) {
    if(!ALLOWED.includes(name) || !Array.isArray(docs))fatal('Collection không được phép trong bản sao.');
    const ids=new Set();
    for(const doc of docs) {
      if(typeof doc.id!=='string' || !doc.id || doc.id.includes('/') || ['.','..'].includes(doc.id) || ids.has(doc.id) || !doc.data || typeof doc.data!=='object' || Array.isArray(doc.data))fatal('Chứng từ sao lưu không hợp lệ hoặc trùng mã.');
      ids.add(doc.id);
      decode(doc.data);
    }
  }
  return body;
}
(async()=>{
  if(command==='verify'||command==='plan') {
    const b=readBackup();
    console.log('SHA-256: HỢP LỆ | project:',b.project,'| store:',b.store,'| thời gian:',b.createdAt);
    for(const [name,docs] of Object.entries(b.collections))console.log(name+': '+docs.length);
    console.log('Sao lưu KHÔNG chứa Firebase Auth/password. Không tự thay đổi dữ liệu production.');
    if(command==='plan') console.log('Kế hoạch: chỉ restore-staging vào store MỚI TRỐNG, không xóa hay ghi đè store thật.');
    return;
  }
  const db=firestore();
  if(command==='backup') {
    const out=getArg('--out');
    if(!out || !path.isAbsolute(out))fatal('Cần --out đường dẫn tuyệt đối.');
    if(fs.existsSync(out))fatal('Không ghi đè bản backup hiện có. Đổi tên file.');
    const base=`stores/${store}`;
    const first=await db.doc(`${base}/meta/state`).get();
    const data={format:'vlxd-firestore-snapshot-1',project,store,createdAt:new Date().toISOString(),
      meta: first.exists?encode(first.data()):null,collections:{}};
    for(const name of ALLOWED){
      const snap=await db.collection(`${base}/${name}`).get();
      data.collections[name]=snap.docs.map(d=>({id:d.id,data:encode(d.data())}));
      console.log(name+' : '+snap.size+' tài liệu');
    }
    const final=await db.doc(`${base}/meta/state`).get();
    const initialRev=first.data()?.revision??0, endingRev=final.data()?.revision??0;
    if(initialRev!==endingRev || first.data()?.generation!==final.data()?.generation)
      fatal('Có giao dịch phát sinh trong khi sao lưu. Không xuất file không nhất quán, thử lại lúc ngừng thao tác.');
    const finalData={...data,sha256:digest(JSON.stringify(data))};
    fs.mkdirSync(path.dirname(out),{recursive:true});
    fs.writeFileSync(out,JSON.stringify(finalData,null,2),{flag:'wx',mode:0o600});
    console.log('Đã sao lưu: '+out);
    console.log('LƯU AN TOÀN: File chứa dữ liệu khách hàng/hóa đơn, không đưa lên GitHub.');
    return;
  }
  // Explicitly refuse in-place restoration of any live store.
  const b=readBackup();
  const target=getArg('--target-store');
  if(!assertId(target||'') || target===b.store || ['bay-hai','hai-soc'].includes(target))
    fatal('--target-store phải là store STAGING MỚI, KHÁC store thật.');
  if(project!==b.project)fatal('Project restore khác project nguồn. Công cụ không tự sao chép chéo dự án.');
  if(!has('--apply')) {
    console.log('Chưa làm gì. Thêm --apply mới nhập vào STAGING trống.');return;
  }
  const prefix=`stores/${target}`;
  const metaRef=db.doc(`${prefix}/meta/state`);
  if((await metaRef.get()).exists)fatal('Staging đã có meta: không ghi đè.');
  for(const name of ALLOWED) {
    const existing=await db.collection(`${prefix}/${name}`).limit(1).get();
    if(!existing.empty)fatal('Staging không trống tại '+name);
  }
  // The destination is empty; no production rows are touched.
  // A partial/competing restore stays visibly occupied and cannot be overwritten.
  await metaRef.create({restoreStatus:'restoring',restoredFrom:b.store});
  for(const [name,docs] of Object.entries(b.collections)){
    for(let i=0;i<docs.length;i+=200){
      const batch=db.batch();
      for(const d of docs.slice(i,i+200)){
        batch.create(db.doc(`${prefix}/${name}/${d.id}`),decode(d.data));
      }
      await batch.commit();
    }
    console.log('staging '+name+' : '+docs.length);
  }
  await metaRef.set({...(decode(b.meta)||{}),restoreStatus:'complete',restoredFrom:b.store,restoredAt:admin.firestore.FieldValue.serverTimestamp()});
  console.log('STAGING RESTORE DONE. Không tác động production.');
})().catch(err=>fatal(err?.message??String(err)));

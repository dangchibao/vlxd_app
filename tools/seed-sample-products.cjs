// Creates only MAU-* products explicitly requested by the owner. Default is a
// read-only plan. No passwords/service-account files are bundled or printed.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cliRoot = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(cliRoot, 'auth.js'));
const { Client } = require(path.join(cliRoot, 'apiv2.js'));
const project = 'vlxd-bay-hai';
const database = `projects/${project}/databases/(default)`;
const root = `${database}/documents`;
const store = `${root}/stores/bay-hai`;
const assets = path.join(__dirname, '../assets/sample-products');
function encode(v) {
  if (v === null) return {nullValue: null};
  if (typeof v === 'boolean') return {booleanValue: v};
  if (typeof v === 'string') return {stringValue: v};
  if (Number.isSafeInteger(v)) return {integerValue: String(v)};
  if (Array.isArray(v)) return {arrayValue: {values: v.map(encode)}};
  if (v && typeof v === 'object') return {mapValue: {fields: Object.fromEntries(Object.entries(v).map(([k,x]) => [k,encode(x)]))}};
  throw new Error('Unsupported Firestore value');
}
function decode(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k,x]) => [k,decode(x)]));
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  return null;
}
const object = doc => decode({mapValue: {fields: doc.fields || {}}});
async function main() {
  const account = auth.getProjectDefaultAccount(path.resolve(__dirname, '..'));
  if (!account) throw new Error('Firebase CLI login is required');
  auth.setActiveAccount({}, account);
  const client = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1'});
  async function list(collection) {
    const docs = []; let pageToken;
    do {
      const res = await client.get(collection, {queryParams: {pageSize: 500, ...(pageToken ? {pageToken} : {})}});
      docs.push(...(res.body.documents || [])); pageToken = res.body.nextPageToken;
      if (docs.length > 5000) throw new Error('Collection unexpectedly large; stopped without writing');
    } while (pageToken);
    return docs;
  }
  const metaResponse = await client.get(`${store}/meta/state`, {resolveOnHTTPError: true});
  if (![200,404].includes(metaResponse.status)) throw new Error(`Cannot inspect revision (${metaResponse.status})`);
  const meta = metaResponse.status === 200 ? metaResponse.body : null;
  const existing = await list(`${store}/products`);
  const owners = (await list(`${root}/users`)).filter(d => {
    const p = object(d); return p.role === 'owner' && p.active && p.mustChangePassword === false;
  }).sort((a,b) => a.createTime.localeCompare(b.createTime));
  if (!owners.length) throw new Error('An active owner profile is required');
  const actor = owners[0].name.split('/').pop();
  const definitions = JSON.parse(fs.readFileSync(path.join(assets, 'catalog.json'), 'utf8'));
  const occupiedCodes = new Set(existing.map(d => object(d).value?.code?.toLowerCase()));
  const occupiedIds = new Set(existing.map(d => d.name.split('/').pop()));
  const missing = definitions.filter(p => !occupiedCodes.has(p.code.toLowerCase()) && !occupiedIds.has(p.id));
  console.log(JSON.stringify({project, mode: process.argv.includes('--apply') ? 'apply' : 'plan',
    existingProducts: existing.length, create: missing.map(p => ({code:p.code, name:p.name, price:p.price, unit:p.size === 'm³' ? 'm³' : 'm²'})),
    skipped: definitions.length - missing.length}));
  if (!missing.length || !process.argv.includes('--apply')) return;
  const mutationId = crypto.randomUUID(), auditId = `commit-${mutationId}`;
  const revision = (meta ? object(meta).revision : 0) + 1;
  const now = new Date().toISOString();
  const envelope = {revision, mutationId, updatedBy: actor};
  function write(name, data, currentDocument = {exists:false}) {
    return {update: {name, fields: encode(data).mapValue.fields}, currentDocument,
      updateTransforms: [{fieldPath:'updatedAt', setToServerValue:'REQUEST_TIME'}]};
  }
  const writes = [write(`${store}/meta/state`, {...envelope,auditId}, meta ? {updateTime:meta.updateTime} : {exists:false})];
  const created = [];
  for (const p of missing) {
    if (!p.id.startsWith('MAU-') || p.price <= 0 || p.quantity <= 0) throw new Error('Invalid sample manifest');
    const image = fs.readFileSync(path.join(assets, p.image));
    if (image.length > 40000) throw new Error('Image too large');
    const lot = `LOT-${p.id}`;
    const value = {id:p.id,code:p.code,name:p.name,size:p.size,supplier:p.supplier,price:p.price,ratio:p.ratio,
      minimum:p.minimum,active:true,images:[image.toString('base64')],
      lots:[{id:lot,date:now,area:p.quantity,reserved:0,cost:p.cost,ratio:p.ratio}]};
    writes.push(write(`${store}/products/${p.id}`, {...envelope,value}));
    const moveId = `SEED-${p.id}`;
    writes.push(write(`${store}/stockMoves/${moveId}`, {...envelope,value:{id:moveId,product:p.code,area:p.quantity,
      type:'Nhập tồn minh họa theo yêu cầu chủ',lot,actor,at:now}}));
    created.push(p.id);
  }
  writes.push(write(`${store}/audit/${auditId}`, {...envelope,value:{id:auditId,actor,at:now,
    action:'Thêm sản phẩm minh họa theo yêu cầu chủ',target:mutationId,
    detail:`${created.join(', ')}. Giá, ảnh AI và tồn kho đều là minh họa; cần sửa/kiểm kê trước khi vận hành.`}}));
  const result = await client.post(`${database}/documents:commit`, {writes});
  const readBack = await Promise.all(created.map(id => client.get(`${store}/products/${id}`)));
  if (readBack.some((r,i) => object(r.body).value.id !== created[i])) throw new Error('Read-back mismatch');
  console.log(JSON.stringify({committed:true,created,revision,commitTime:result.body.commitTime,verified:readBack.length}));
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });

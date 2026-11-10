import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } from 'firebase/firestore';

let env;
const path = 'stores/bay-hai';
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-vlxd-tests', firestore: {
    host: '127.0.0.1', port: 8080,
    rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const [uid, role, active] of [['owner','owner',true],['sales','sales',true],['driver','driver',true],['locked','sales',false]]) {
      await setDoc(doc(c.firestore(), `users/${uid}`), {role,active,displayName:uid,mustChangePassword:false});
    }
  });
});
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
function commit(firestore, uid, mutationId, records, revision = 1) {
  const batch = writeBatch(firestore);
  const envelope = { revision, mutationId, updatedBy: uid, updatedAt: serverTimestamp() };
  const auditId = `commit-${mutationId}`;
  batch.set(doc(firestore, `${path}/meta/state`), {...envelope,auditId});
  batch.set(doc(firestore, `${path}/audit/${auditId}`), {...envelope,value:{id:auditId,actor:uid,action:'test',target:mutationId,detail:'test',at:'2026-11-03'}});
  for (const [collection, value] of records) batch.set(doc(firestore, `${path}/${collection}/${value.id}`), {...envelope,value});
  return batch.commit();
}
const product = {id:'P1',code:'P1',name:'Prime',size:'60×60',supplier:'Prime',price:240000,ratio:14400,minimum:0,active:true,images:[],lots:[]};

test('optional product note and unknown conversion are accepted without widening staff permissions', async () => {
  await assertSucceeds(commit(db('sales'),'sales','note1',[['products',{...product,note:'5 tấm; người bán tự tính m²',ratio:0,size:'',supplier:''}]]));
  await assertFails(commit(db('driver'),'driver','note2',[['products',{...product,note:'Denied'}]],2));
});
test('invalid note type, oversized notes and negative conversion are denied', async () => {
  await assertFails(commit(db('sales'),'sales','bad-note-type',[['products',{...product,note:123}]]));
  await assertFails(commit(db('sales'),'sales','bad-note-size',[['products',{...product,note:'x'.repeat(1001)}]]));
  await assertFails(commit(db('sales'),'sales','bad-ratio',[['products',{...product,ratio:-1}]]));
});
test('unauthenticated, unprovisioned, driver and locked users cannot read store', async () => {
  for (const uid of [null,'unknown','driver','locked']) await assertFails(getDoc(doc(db(uid), `${path}/meta/state`)));
});
test('sales and owner read store, profiles cannot be enumerated by sales', async () => {
  await assertSucceeds(getDoc(doc(db('sales'), `${path}/meta/state`)));
  await assertSucceeds(getDoc(doc(db('sales'), 'users/sales')));
  await assertFails(getDoc(doc(db('sales'), 'users/owner')));
});
test('valid sales product transaction includes immutable audit', async () => {
  await assertSucceeds(commit(db('sales'),'sales','m1',[['products',product]]));
  await assertFails(updateDoc(doc(db('sales'), `${path}/audit/commit-m1`), {'value.detail':'erase'}));
  await assertFails(deleteDoc(doc(db('owner'), `${path}/audit/commit-m1`)));
});
test('uncoordinated updates and stale revisions are denied', async () => {
  await assertSucceeds(commit(db('sales'),'sales','m1',[['products',product]]));
  await assertFails(updateDoc(doc(db('sales'), `${path}/products/P1`), {'value.price':1}));
  await assertFails(commit(db('sales'),'sales','m2',[['products',{...product,price:200000}]],1));
  await assertSucceeds(commit(db('sales'),'sales','m2',[['products',{...product,price:200000}]],2));
});
test('owner and sales can edit payroll, other roles remain blocked', async () => {
  const value = {id:'N1',name:'Hùng',salary:8000000,advance:0};
  await assertSucceeds(commit(db('sales'),'sales','m1',[['payroll',value]]));
  await assertSucceeds(commit(db('owner'),'owner','m2',[['payroll',value]],2));
  for (const uid of ['driver','locked','unknown']) await assertFails(commit(db(uid),uid,'denied',[['payroll',value]],3));
  await assertSucceeds(getDoc(doc(db('sales'), `${path}/payroll/N1`)));
});
test('sales cannot grant roles, disable another user or self-promote', async () => {
  await assertFails(updateDoc(doc(db('sales'),'users/sales'),{role:'owner'}));
  await assertFails(updateDoc(doc(db('sales'),'users/owner'),{active:false}));
  await assertFails(setDoc(doc(db('unknown'),'users/unknown'),{role:'owner',active:true,displayName:'x',mustChangePassword:false}));
  await assertSucceeds(updateDoc(doc(db('owner'),'users/sales'),{active:false}));
  await assertFails(updateDoc(doc(db('owner'),'users/owner'),{active:false}));
});
test('password-change flag cannot change role or reactivate disabled user', async () => {
  await assertSucceeds(updateDoc(doc(db('sales'),'users/sales'),{mustChangePassword:false}));
  await assertFails(updateDoc(doc(db('locked'),'users/locked'),{mustChangePassword:false}));
});
test('orders require unique request record and totals cannot be rewritten', async () => {
  const order = {id:'DH1',requestId:'request1',actor:'sales',customerId:'',status:'Đã bán',total:100,subtotal:100,ship:0,lines:[{name:'Prime'}],payments:[]};
  await assertFails(commit(db('sales'),'sales','m1',[['orders',order]]));
  await assertSucceeds(commit(db('sales'),'sales','m1',[['orders',order],['requests',{id:'request1',orderId:'DH1'}]]));
  await assertFails(commit(db('sales'),'sales','m2',[['orders',{...order,total:200,subtotal:200}]],2));
  await assertFails(commit(db('sales'),'sales','m2',[['orders',{...order,id:'DH2'}],['requests',{id:'request1',orderId:'DH2'}]],2));
});
test('discounted order keeps net subtotal compatible with rules and discount immutable', async () => {
  const order = {id:'DH1',requestId:'discount-order',actor:'sales',customerId:'',status:'Đã bán',subtotal:75000,discount:25000,ship:50000,total:125000,lines:[{name:'Prime',amount:100000}],payments:[]};
  await assertSucceeds(commit(db('sales'),'sales','discount1',[['orders',order],['requests',{id:order.requestId,orderId:order.id}]]));
  await assertFails(commit(db('sales'),'sales','discount2',[['orders',{...order,discount:50000}]],2));
});

test('delete product, forged audit actor, unknown collections and other stores denied', async () => {
  await assertSucceeds(commit(db('sales'),'sales','m1',[['products',product]]));
  await assertFails(deleteDoc(doc(db('owner'),`${path}/products/P1`)));
  await assertFails(commit(db('sales'),'owner','m2',[['products',product]],2));
  await assertFails(commit(db('owner'),'owner','m2',[['secrets',{id:'X'}]],2));
  await assertFails(getDoc(doc(db('owner'),'stores/another/meta/state')));
});
test('commit without corresponding audit is denied', async () => {
  await assertFails(setDoc(doc(db('sales'),`${path}/meta/state`),{revision:1,mutationId:'bad',auditId:'commit-bad',updatedBy:'sales',updatedAt:serverTimestamp()}));
});

test('sales can adjust and archive customer books with immutable audit, physical deletion stays blocked', async () => {
  const customer={id:'C1',name:'Khách',phone:'0900000000'};
  await assertSucceeds(commit(db('sales'),'sales','c1',[['customers',customer]]));
  const adjusted={...customer,receivableAdjustment:1000000,receivedAdjustment:200000,ledgerVersion:1};
  await assertSucceeds(commit(db('sales'),'sales','c2',[['customers',adjusted]],2));
  for(const uid of ['driver','locked','unknown']) {
    await assertFails(commit(db(uid),uid,'blocked',[['customers',adjusted]],3));
  }
  await assertSucceeds(commit(db('sales'),'sales','c3',[['customers',{...adjusted,active:false}]],3));
  await assertFails(deleteDoc(doc(db('sales'),`${path}/customers/C1`)));
  await assertFails(commit(db('sales'),'sales','c4',[['customers',{...adjusted,role:'owner'}]],4));
});

test('customer and payroll validation still reject malformed data', async () => {
  await assertFails(commit(db('sales'),'sales','inject',[['customers',{id:'C1',name:'Khách',phone:'',receivableAdjustment:1}]]));
  await assertFails(commit(db('sales'),'sales','salary-negative',[['payroll',{id:'N1',salary:-1,advance:0}]]));
  await assertFails(commit(db('sales'),'sales','advance-excess',[['payroll',{id:'N1',salary:100,advance:101}]]));
});

test('sales can correct receipts while invoice totals remain immutable', async () => {
  const order={id:'DH1',requestId:'receipt-order',actor:'sales',customerId:'C1',status:'Đã bán',total:1000,subtotal:1000,ship:0,
    lines:[{name:'Gạch'}],payments:[{id:'initial',amount:100}]};
  await assertSucceeds(commit(db('sales'),'sales','receipt1',[['orders',order],['requests',{id:'receipt-order',orderId:'DH1'}]]));
  const corrected={...order,payments:[{...order.payments[0],voided:true},{id:'fix',amount:50}]};
  await assertSucceeds(commit(db('sales'),'sales','receipt2',[['orders',corrected]],2));
  await assertFails(commit(db('sales'),'sales','receipt3',[['orders',{...corrected,total:2000,subtotal:2000}]],3));
});



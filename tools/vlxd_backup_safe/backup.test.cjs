'use strict';
const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const admin=require('firebase-admin');

const project='demo-vlxd-tests';
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) {
  if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[name]??''))throw Error('Local emulators required');
}
admin.initializeApp({projectId:project});
const db=admin.firestore(), auth=admin.auth();
after(()=>admin.app().delete());

test('backup/verify/restore round trip preserves ledgers and Auth; live/occupied targets are blocked', async()=>{
  const suffix=Date.now(), source=`source-${suffix}`, target=`stage-${suffix}`;
  const directory=path.resolve('.qa/backup-drill');
  fs.mkdirSync(directory,{recursive:true});
  const file=path.join(directory,`snapshot-${suffix}.json`);
  const user=await auth.createUser({email:`restore-${suffix}@example.test`,password:'Emulator-only-12345'});
  const stamp=admin.firestore.Timestamp.fromMillis(1795300000000);
  const fixtures={
    products:[{id:'P1',value:{id:'P1',name:'Gạch mẫu',unit:'m²',images:['dGVzdA=='],lots:[{id:'L1',area:120000,reserved:20000,cost:100000}]}}],
    customers:[{id:'C1',value:{id:'C1',name:'Khách mẫu',receivableAdjustment:0,receivedAdjustment:0}}],
    orders:[{id:'DH1',value:{id:'DH1',customerId:'C1',total:500000,payments:[{id:'T1',amount:200000}]}}],
    stockMoves:[{id:'K1',value:{id:'K1',productId:'P1',area:120000}}],
    payroll:[{id:'N1',value:{id:'N1',salary:8000000,advance:1000000}}],
    deliveries:[{id:'GH1',value:{id:'GH1',orderId:'DH1',status:'Đang giao'}}],
    requests:[{id:'R1',value:{id:'R1',orderId:'DH1'}}],
    audit:[{id:'A1',value:{id:'A1',actor:user.uid,action:'Fixture',detail:'Mẫu'}}],
    notifications:[],
  };
  await db.doc(`stores/${source}/meta/state`).set({revision:7,generation:'reset-20261113'});
  for(const [collection,docs] of Object.entries(fixtures))for(const doc of docs){
    await db.doc(`stores/${source}/${collection}/${doc.id}`).set({...doc,revision:7,updatedAt:stamp});
  }
  const command=(...args)=>{
    const result=spawnSync(process.execPath,[path.join(__dirname,'vlxd-backup.cjs'),...args,'--project',project,'--store',source],{env:process.env,encoding:'utf8',timeout:30000});
    if(result.error)throw result.error;
    return result;
  };
  assert.equal(command('backup','--out',file).status,0);
  assert.equal(command('verify','--file',file).status,0);
  const body=JSON.parse(fs.readFileSync(file,'utf8'));
  assert.equal(body.collections.products[0].data.value.images[0],'dGVzdA==');
  assert.equal('users' in body.collections,false);
  for(const forbidden of ['bay-hai','hai-soc',source]){
    assert.notEqual(command('restore-staging','--file',file,'--target-store',forbidden,'--apply').status,0);
  }
  assert.equal(command('restore-staging','--file',file,'--target-store',target,'--apply').status,0);
  for(const [collection,docs] of Object.entries(fixtures)){
    const restored=await db.collection(`stores/${target}/${collection}`).get();
    assert.equal(restored.size,docs.length);
    for(const doc of docs){
      assert.deepEqual((await db.doc(`stores/${target}/${collection}/${doc.id}`).get()).data(),
        (await db.doc(`stores/${source}/${collection}/${doc.id}`).get()).data());
    }
  }
  const state=(await db.doc(`stores/${target}/meta/state`).get()).data();
  assert.equal(state.restoreStatus,'complete');
  assert.equal(state.revision,7);
  assert.equal(state.generation,'reset-20261113');
  assert.equal((await auth.getUser(user.uid)).email,`restore-${suffix}@example.test`);
  assert.notEqual(command('restore-staging','--file',file,'--target-store',target,'--apply').status,0);
  body.collections.products[0].data.value.lots[0].area=1;
  const corrupt=path.join(directory,`corrupt-${suffix}.json`);
  fs.writeFileSync(corrupt,JSON.stringify(body));
  assert.notEqual(command('verify','--file',corrupt).status,0);
  const {sha256,...invalid}=body;
  invalid.collections.users=[];
  invalid.sha256=crypto.createHash('sha256').update(JSON.stringify(invalid)).digest('hex');
  fs.writeFileSync(corrupt,JSON.stringify(invalid));
  assert.notEqual(command('verify','--file',corrupt).status,0);
});

// Run only on a trusted admin machine with Application Default Credentials.
// Never bundle this file, an Admin SDK credential or a secret into Flutter.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const [uid, projectId] = process.argv.slice(2);
if (!uid || projectId !== 'vlxd-bay-hai') throw new Error('Pass target UID and explicit project ID vlxd-bay-hai.');
let password = process.env.BAYHAI_TEMP_PASSWORD;
if (!password || password.length < 10) throw new Error('Set BAYHAI_TEMP_PASSWORD locally to a temporary password of at least 10 characters. Do not paste it in chat or commit it.');
delete process.env.BAYHAI_TEMP_PASSWORD;
initializeApp({ projectId, credential: applicationDefault() });
const auth = getAuth(), db = getFirestore();
await auth.getUser(uid);
const profile = db.doc(`users/${uid}`);
if (!(await profile.get()).exists) throw new Error('No staff profile; reconcile UID first. No role will be created.');
// Close access before changing the password; failures remain fail-closed.
await profile.update({ mustChangePassword: true });
await auth.updateUser(uid, { password });
password = undefined;
await auth.revokeRefreshTokens(uid);
await db.collection('accountAudit').add({ actor: 'trusted-admin-tool', target: uid,
  action: 'Đặt lại mật khẩu tạm và thu hồi phiên', at: FieldValue.serverTimestamp() });
console.log(`Temporary password reset for UID ${uid}. Role and active flag unchanged.`);

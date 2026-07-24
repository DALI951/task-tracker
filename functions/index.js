const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

async function isManager(uid) {
  const doc = await db.doc(`users/${uid}`).get();
  return doc.exists && doc.data().role === 'manager';
}

async function setEmployeeData(user, email, name, password, managerEmail) {
  await db.doc(`users/${user.uid}`).set({
    role: 'employee',
    email,
    name,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.doc(`employees/${email}`).set({
    email,
    name,
    createdBy: managerEmail,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    storedPassword: password,
  });
}

exports.createEmployee = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated', 'Must be signed in'
    );
  }

  const isMgr = await isManager(context.auth.uid);
  if (!isMgr) {
    throw new functions.https.HttpsError(
      'permission-denied', 'Only managers can create employees'
    );
  }

  const { email, name, password, mode } = data;
  if (!email || !name || !password || password.length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Email, name, and password (min 6 chars) required'
    );
  }

  const managerEmail = (await admin.auth().getUser(context.auth.uid)).email || '';

  try {
    if (mode === 'replace') {
      const existing = await admin.auth().getUserByEmail(email);
      await admin.auth().deleteUser(existing.uid);
      const user = await admin.auth().createUser({ email, password, displayName: name });
      await setEmployeeData(user, email, name, password, managerEmail);
      return { success: true, uid: user.uid, action: 'replaced' };
    }

    if (mode === 'link') {
      const existing = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(existing.uid, { password, displayName: name });
      const linkedEmail = existing.email || email;
      await db.doc(`users/${existing.uid}`).set({
        role: 'employee',
        email: linkedEmail,
        name,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await db.doc(`employees/${email}`).set({
        email,
        name,
        createdBy: managerEmail,
        storedPassword: password,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return { success: true, uid: existing.uid, action: 'linked' };
    }

    // Default: create new
    const user = await admin.auth().createUser({ email, password, displayName: name });
    await setEmployeeData(user, email, name, password, managerEmail);
    return { success: true, uid: user.uid, action: 'created' };
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Email already in use');
    }
    throw new functions.https.HttpsError('internal', e.message);
  }
});

exports.setEmployeePassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated', 'Must be signed in'
    );
  }

  const isMgr = await isManager(context.auth.uid);
  if (!isMgr) {
    throw new functions.https.HttpsError(
      'permission-denied', 'Only managers can change employee passwords'
    );
  }

  const { email, newPassword } = data;
  if (!email || !newPassword || newPassword.length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Email and new password (min 6 chars) required'
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });
    await db.doc(`employees/${email}`).update({ storedPassword: newPassword });
    return { success: true };
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    throw new functions.https.HttpsError('internal', e.message);
  }
});

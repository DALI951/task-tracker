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
  });
}

// A manager may only modify an employee they created (or legacy ones created
// via the old web_admin page). Missing employees docs are treated as owned.
// A manager can never register or manage their own account as an employee.
async function assertCanManageEmployee(managerEmail, employeeEmail) {
  if (!managerEmail || employeeEmail.toLowerCase() === managerEmail.toLowerCase()) {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Cannot use your own account as an employee'
    );
  }
  const empDoc = await db.doc(`employees/${employeeEmail}`).get();
  if (!empDoc.exists) return;
  const createdBy = empDoc.data().createdBy;
  if (createdBy === managerEmail || createdBy === 'web_admin') return;
  throw new functions.https.HttpsError(
    'permission-denied', 'This employee was created by another manager'
  );
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
      await assertCanManageEmployee(managerEmail, email);
      const existing = await admin.auth().getUserByEmail(email);
      await admin.auth().deleteUser(existing.uid);
      const user = await admin.auth().createUser({ email, password, displayName: name });
      await setEmployeeData(user, email, name, password, managerEmail);
      return { success: true, uid: user.uid, action: 'replaced' };
    }

    if (mode === 'link') {
      await assertCanManageEmployee(managerEmail, email);
      const existing = await admin.auth().getUserByEmail(email);
      // "Use existing": keep the existing password, only update the name/role.
      await admin.auth().updateUser(existing.uid, { displayName: name });
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return { success: true, uid: existing.uid, action: 'linked' };
    }

    // Default: create new
    await assertCanManageEmployee(managerEmail, email);
    const user = await admin.auth().createUser({ email, password, displayName: name });
    await setEmployeeData(user, email, name, password, managerEmail);
    return { success: true, uid: user.uid, action: 'created' };
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Email already in use');
    }
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
    throw new functions.https.HttpsError('internal', e.message);
  }
});

exports.deleteEmployee = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated', 'Must be signed in'
    );
  }

  if (!(await isManager(context.auth.uid))) {
    throw new functions.https.HttpsError(
      'permission-denied', 'Only managers can delete employees'
    );
  }

  const { email } = data;
  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Email required'
    );
  }

  try {
    const managerEmail = (await admin.auth().getUser(context.auth.uid)).email || '';
    await assertCanManageEmployee(managerEmail, email);

    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().deleteUser(user.uid);
    await db.doc(`users/${user.uid}`).delete().catch(() => {});
    await db.doc(`employees/${email}`).delete();

    return { success: true };
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      await db.doc(`employees/${email}`).delete().catch(() => {});
      return { success: true };
    }
    if (e instanceof functions.https.HttpsError) {
      throw e;
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
    const managerEmail = (await admin.auth().getUser(context.auth.uid)).email || '';
    await assertCanManageEmployee(managerEmail, email);
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });
    return { success: true };
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
    throw new functions.https.HttpsError('internal', e.message);
  }
});

// Pushes a notification to the recipient's device when a notification
// document is created. Replaces the client-side FCM sender that shipped a
// service account inside the app binaries.
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    try {
      const data = snap.data() || {};
      const recipientEmail = data.recipientEmail;
      if (!recipientEmail) return;

      const users = await db.collection('users')
        .where('email', '==', recipientEmail)
        .limit(1)
        .get();
      if (users.empty) return;

      const fcmToken = users.docs[0].data().fcmToken;
      if (!fcmToken) return;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: String(data.title || 'Task Tracker'),
          body: String(data.message || ''),
        },
        data: {
          type: String(data.type || ''),
          relatedId: String(data.relatedId || ''),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
        },
      });
    } catch (e) {
      functions.logger.warn('Failed to send FCM notification', e);
    }
  });

// Tags a reported problem with the manager email of the reporting employee,
// so managers only see problems belonging to their own employees.
exports.onProblemCreated = functions.firestore
  .document('problems/{problemId}')
  .onCreate(async (snap) => {
    try {
      const data = snap.data() || {};
      if (data.managerEmail) return;

      const reportedBy = data.reportedBy;
      if (!reportedBy) return;

      const empDoc = await db.doc(`employees/${reportedBy}`).get();
      if (!empDoc.exists) return;

      const managerEmail = empDoc.data().createdBy || null;
      if (!managerEmail) return;

      await snap.ref.update({ managerEmail });
    } catch (e) {
      functions.logger.warn('Failed to tag problem managerEmail', e);
    }
  });

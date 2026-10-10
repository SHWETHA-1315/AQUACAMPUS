'use strict';
// Owner-authorized push sender for Firebase project aquacampus-ed284.
// IMPORTANT: this file is never executed inside the Android APK. Deploying
// Firebase Functions requires a Blaze billing-linked project.
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
initializeApp();
const db = getFirestore();
const region = 'asia-south1';
const emergency = {title:'AQUACAMPUS water SOS',
  description:'A new water emergency requires authorized staff attention.'};
const request = {title:'Water request',
  description:'A water request needs attention in your authorized portal.'};
const requestChanged = {title:'Water request updated',
  description:'The status of an authorized water request changed.'};
const notice = {title:'Campus announcement',
  description:'A notice for your campus or assigned area is available.'};
const reading = {title:'Water level update',
  description:'A water tank measurement has been updated.'};
const member = {title:'Account access updated',
  description:'Your campus access or assigned role was updated.'};

async function activeMembers() {
  const snap = await db.collection('users').where('campusId','==','main')
      .where('approved','==',true).get();
  return snap.docs.map(d=>({id:d.id,...d.data()}));
}
const operators = u => u.role === 'worker' || u.role === 'admin';
const actor = (u,id) => u.id === id;
async function noticeAudience(users, facilityId) {
  if (!facilityId) return users;
  const f = await db.doc('campuses/main/facilities/'+facilityId).get();
  const type = f.exists ? f.data().type : null;
  return users.filter(u => operators(u) || u.facilityId === facilityId ||
      (['teacher','staff'].includes(u.role) && ['college','canteen'].includes(type)));
}
async function deliver(eventId, kind, copy, users) {
  const unique = [...new Set(users.map(u => u.id))];
  for (const uid of unique) {
    try {
      // Recheck role and approval at send time. Do not subscribe to public
      // topics or trust a device-supplied role/recipient list.
      const profile = await db.doc('users/'+uid).get();
      if (!profile.exists || profile.data().approved !== true ||
          profile.data().campusId !== 'main') continue;
      const notification = db.doc('users/'+uid+'/inbox/'+eventId);
      // Idempotent inbox record; no sensitive document data is copied.
      try {
        await notification.create({
          title:copy.title,description:copy.description,kind,
          eventId,createdAt:new Date().toISOString()
        });
      } catch(e) {
        if (e.code === 6 || e.code === 'already-exists') continue;
        throw e;
      }
      const devices = await profile.ref.collection('devices').limit(30).get();
      const tokens = [...new Set(devices.docs.map(d=>d.data().token)
          .filter(t=>typeof t==='string'&&t.length>=20))];
      if (!tokens.length) continue;
      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {title:copy.title,body:copy.description},
        data: {kind,eventId},
        android: {priority: kind==='sos'?'high':'normal',
          notification: {channelId:'campus_updates'}},
      });
      // Delete obsolete tokens only when the SDK explicitly rejects them.
      await Promise.all(response.responses.map(async (one,i) => {
        if (one.success) return;
        const code = one.error?.code || '';
        if (code==='messaging/registration-token-not-registered' ||
            code==='messaging/invalid-registration-token') {
          await Promise.all(devices.docs.filter(d=>d.data().token===tokens[i])
              .map(d=>d.ref.delete()));
        }
      }));
    } catch(err) {
      console.error('Safe generic alert send failed',eventId,uid,err.code||err.message);
    }
  }
}

exports.onSOSCreated = onDocumentCreated(
    {document:'campuses/main/sos/{alertId}',region},
    async event => {
      if (!event.data || event.data.data().status !== 'open') return;
      const users = await activeMembers();
      await deliver('sos_'+event.params.alertId,'sos',emergency,
          users.filter(operators));
    });

exports.onRequestCreated = onDocumentCreated(
    {document:'campuses/main/requests/{requestId}',region},
    async event => {
      if (!event.data) return;
      const users = await activeMembers();
      await deliver('newrequest_'+event.params.requestId,'request',request,
          users.filter(operators));
    });

exports.onRequestUpdated = onDocumentUpdated(
    {document:'campuses/main/requests/{requestId}',region},
    async event => {
      if (!event.data) return;
      const before=event.data.before.data(),after=event.data.after.data();
      if (before.status === after.status) return;
      const users=await activeMembers();
      await deliver('request_'+event.params.requestId+'_'+after.status,
          'request',requestChanged,
          users.filter(u=>operators(u)||actor(u,after.requestedBy)));
    });

exports.onNoticeCreated = onDocumentCreated(
    {document:'campuses/main/notices/{noticeId}',region},
    async event => {
      if (!event.data) return;
      const users=await activeMembers();
      const recipients=await noticeAudience(users,event.data.data().targetFacilityId||'');
      await deliver('notice_'+event.params.noticeId,'notice',notice,recipients);
    });

exports.onTankUpdated = onDocumentUpdated(
    {document:'campuses/main/tanks/{tankId}',region},
    async event => {
      if (!event.data) return;
      const before=event.data.before.data(), after=event.data.after.data();
      if (before.lastMeasuredAt === after.lastMeasuredAt) return;
      const users=await activeMembers();
      const recipients=await noticeAudience(users, after.facilityId);
      await deliver('tank_'+event.params.tankId+'_'
        +String(after.lastMeasuredAt||'').replace(/[^\w]/g,'_'),
        'tank',reading,recipients);
    });

exports.onMemberUpdated = onDocumentUpdated(
    {document:'users/{userId}',region},
    async event => {
      if (!event.data) return;
      const before=event.data.before.data(),after=event.data.after.data();
      if (before.approved===after.approved && before.role===after.role &&
          before.facilityId===after.facilityId) return;
      if (after.approved !== true) return;
      const users=await activeMembers();
      await deliver('account_'+event.params.userId+'_'
        +String(event.id).replace(/[^\w]/g,'_'),
        'account',member,users.filter(u=>actor(u,event.params.userId)));
    });

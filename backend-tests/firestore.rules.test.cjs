// Offline Firebase emulator tests ONLY. No production accounts are created.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} =
  require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, writeBatch} =
  require('firebase/firestore');

const projectId = 'demo-aquacampus-rules';
const time = '2026-10-08T07:00:00.000Z';
const facility = (type = 'hostel') => ({
  name: type === 'canteen' ? 'Real Canteen' : 'Real Hostel',
  type,
  occupants: type === 'hostel' ? 3 : 0,
  floors: 2,
  restrooms: 3,
  dailyCapLitres: type === 'canteen' ? 100 : 0,
  lowWaterThresholdLitres: 30,
  essentialLitresPerResident: type === 'hostel' ? 30 : 1,
  createdAt: time
});
const tank = () => ({
  name:'Water tank A',facilityId:'hostel-1',shape:'rect',
  lengthCm:100,widthCm:100,heightCm:100,diameterCm:0,
  waterHeightCm:0,lastMeasuredAt:'',createdAt:time
});
const profile = (email, role, approved, facilityId = 'hostel-1') => ({
  name: email.split('@')[0], email, role, approved,
  campusId:'main',facilityId,room:'104',createdAt:time
});
const waterRequest = (requestedBy = 'student') => ({
  facilityId:'hostel-1',activity:'Laundry',peopleCount:2,
  litresPerPerson:15,quantityLitres:30,
  approvedLitres:0,notes:'Clothes wash',requestedBy,
  requestedByName:'Student',room:'104',status:'pending',createdAt:time,
  approvedBy:'',fulfilledBy:'',fulfilledAt:''
});

let env;
function context(id, email, verified = true) {
  return env.authenticatedContext(id,
    {email, email_verified: verified}).firestore();
}
const path = (root, tail) => 'campuses/main/' + root + '/' + tail;
test.before(async () => {
  env = await initializeTestEnvironment({
    projectId, firestore:{host:'127.0.0.1',port:8080,
      rules: fs.readFileSync('firestore.rules', 'utf8')}
  });
});
test.after(async () => { if (env) await env.cleanup(); });
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db=ctx.firestore();
    for (const [id,email,role,approved,facilityId] of [
      ['admin','admin@campus.test','admin',true,''],
      ['admin2','admin2@campus.test','admin',true,''],
      ['worker','worker@campus.test','worker',true,''],
      ['warden','warden@campus.test','warden',true,'hostel-1'],
      ['student','student@campus.test','student',true,'hostel-1'],
      ['second','second@campus.test','student',true,'hostel-1'],
      ['teacher','teacher@campus.test','teacher',true,''],
      ['staff','staff@campus.test','staff',true,''],
      ['canteen','canteen@campus.test','canteen',true,'canteen-1'],
      ['gardener','gardener@campus.test','gardener',true,'garden-1'],
      ['driver','driver@campus.test','driver',true,'transport-1'],
      ['daystudent','daystudent@campus.test','student',true,'canteen-1'],
      ['pending','pending@campus.test','student',false,''],
    ]) {
      await setDoc(doc(db, 'users', id), profile(email,role,approved,facilityId));
    }
    await setDoc(doc(db, path('facilities','hostel-1')),facility());
    await setDoc(doc(db, path('facilities','canteen-1')),facility('canteen'));
    await setDoc(doc(db, path('facilities','garden-1')),facility('garden'));
    await setDoc(doc(db, path('facilities','transport-1')),facility('transport'));
    await setDoc(doc(db, path('tanks','tank-1')),tank());
    await setDoc(doc(db,path('requests','request-1')),waterRequest());
    await setDoc(doc(db,path('requests','second-request')),waterRequest('second'));
  });
});
test('anonymous and unapproved accounts cannot read campus records', async () => {
  const anon=env.unauthenticatedContext().firestore();
  const pending=context('pending','pending@campus.test');
  await assertFails(getDoc(doc(anon,path('facilities','hostel-1'))));
  await assertFails(getDoc(doc(pending,path('facilities','hostel-1'))));
  const unverified=context('student','student@campus.test',false);
  await assertFails(getDoc(doc(unverified,path('facilities','hostel-1'))));
});
test('registration creates only an unapproved student, without arbitrary fields', async () => {
  const db=context('fresh','fresh@campus.test');
  const valid=profile('fresh@campus.test','student',false,'');
  valid.room='';
  await assertSucceeds(setDoc(doc(db,'users','fresh'),valid));
  await assertFails(setDoc(doc(db,'users','fresh-other'),valid));
  const db2=context('new2','new2@campus.test');
  await assertFails(setDoc(doc(db2,'users','new2'),
    {...valid,email:'new2@campus.test',role:'admin',approved:true}));
});
test('students cannot grant themselves privileges or see other private requests',async()=>{
  const db=context('student','student@campus.test');
  await assertFails(updateDoc(doc(db,'users','student'),{approved:true,role:'admin'}));
  await assertFails(getDoc(doc(db,path('requests','second-request'))));
  await assertSucceeds(getDocs(query(collection(db,path('requests','placeholder').replace('/placeholder','')),
    where('requestedBy','==','student'))));
  await assertFails(getDocs(collection(db,'campuses/main/requests')));
});
test('admin alone can edit facilities but cannot change original type',async()=>{
  const db=context('admin','admin@campus.test');
  const student=context('student','student@campus.test');
  await assertSucceeds(setDoc(doc(db,path('facilities','hostel-2')),facility()));
  await assertFails(setDoc(doc(student,path('facilities','hostel-3')),facility()));
  await assertSucceeds(updateDoc(doc(db,path('facilities','hostel-1')),
    {occupants:5,lowWaterThresholdLitres:40,updatedAt:time,updatedBy:'admin'}));
  await assertFails(updateDoc(doc(db,path('facilities','hostel-1')),{type:'canteen',updatedBy:'admin'}));
  await assertFails(updateDoc(doc(db,path('facilities','hostel-1')),{occupants:-8,updatedBy:'admin'}));
  await assertFails(updateDoc(doc(db,'users','admin'), {approved:false}));
});
test('worker manual tank updates have an immutable, linked audit record',async()=>{
  const db=context('worker','worker@campus.test');
  const docRef=doc(db,path('tanks','tank-1'));
  const reading=doc(db,path('tankReadings','reading-1'));
  const batch=writeBatch(db);
  batch.update(docRef,{waterHeightCm:23,lastMeasuredAt:time,updatedBy:'worker'});
  batch.set(reading,{tankId:'tank-1',facilityId:'hostel-1',waterHeightCm:23,
    estimatedLitres:230,measuredAt:time,recordedBy:'worker'});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(reading,{waterHeightCm:80}));
  await assertFails(updateDoc(docRef,{shape:'cylinder',updatedBy:'worker'}));
  await assertFails(setDoc(doc(db,path('tankReadings','forged')),{
    tankId:'tank-1',facilityId:'canteen-1',waterHeightCm:2,
    estimatedLitres:20,measuredAt:time,recordedBy:'worker'}));
  // The tank is now at 23 cm (230 L); an invented litre estimate is rejected.
  await assertFails(setDoc(doc(db,path('tankReadings','wrong-litres')),{
    tankId:'tank-1',facilityId:'hostel-1',waterHeightCm:23,
    estimatedLitres:99999,measuredAt:time,recordedBy:'worker'}));
});
test('student can send real request but cannot approve it',async()=>{
  const db=context('student','student@campus.test');
  await assertSucceeds(setDoc(doc(db,path('requests','request-2')),waterRequest()));
  await assertFails(updateDoc(doc(db,path('requests','request-2')),
    {status:'approved',approvedLitres:20,approvedBy:'student',reviewedAt:time}));
  await assertFails(setDoc(doc(db,path('requests','fake-quantity')),
    {...waterRequest(),quantityLitres:500}));
});
test('worker can approve and fulfill valid requests, not bypass approval',async()=>{
  const db=context('worker','worker@campus.test');
  await assertFails(updateDoc(doc(db,path('requests','request-1')),
    {status:'fulfilled',fulfilledBy:'worker',fulfilledAt:time}));
  await assertSucceeds(updateDoc(doc(db,path('requests','request-1')),
    {status:'approved',approvedLitres:20,approvedBy:'worker',reviewedAt:time}));
  await assertSucceeds(updateDoc(doc(db,path('requests','request-1')),
    {status:'fulfilled',fulfilledBy:'worker',fulfilledAt:time}));
});
test('warden requests limited to own hostel',async()=>{
  const db=context('warden','warden@campus.test');
  await assertFails(getDoc(doc(db,path('requests','request-1'))));
  await assertFails(setDoc(doc(db,path('requests','canteen-attempt')),
    {...waterRequest('warden'),facilityId:'canteen-1'}));
});
test('warden cannot see any other resident requests, even from own hostel',async()=>{
  const db=context('warden','warden@campus.test');
  await assertFails(getDocs(query(collection(db,'campuses/main/requests'),
    where('facilityId','==','hostel-1'))));
  await assertSucceeds(getDocs(query(collection(db,'campuses/main/requests'),
    where('requestedBy','==','warden'))));
  await assertFails(getDocs(collection(db,'campuses/main/requests')));
});
test('canteen daily usage cap cannot be bypassed',async()=>{
  const db=context('worker','worker@campus.test');
  const valid={facilityId:'canteen-1',day:'2026-10-08',usedLitres:95,updatedBy:'worker'};
  await assertSucceeds(setDoc(doc(db,path('dailyUsage','2026-10-08_canteen-1')),valid));
  await assertFails(updateDoc(doc(db,path('dailyUsage','2026-10-08_canteen-1')),
    {usedLitres:125}));
});
test('SOS can be reported but only staff can read incident details',async()=>{
  const student=context('student','student@campus.test');
  const worker=context('worker','worker@campus.test');
  const report={facilityId:'hostel-1',floor:1,restroom:'Restroom 2',
    detail:'Water leakage at the pipe',createdBy:'student',
    createdByName:'Student',status:'open',createdAt:time,resolvedAt:''};
  await assertSucceeds(setDoc(doc(student,path('sos','incident-1')),report));
  await assertSucceeds(getDoc(doc(student,path('sos','incident-1'))));
  await assertFails(getDoc(doc(context('second','second@campus.test'),path('sos','incident-1'))));
  await assertSucceeds(getDoc(doc(worker,path('sos','incident-1'))));
  await assertSucceeds(updateDoc(doc(worker,path('sos','incident-1')),
    {status:'resolved',resolvedBy:'worker',resolvedAt:time}));
});
test('admin notices are visible to approved members, never unapproved',async()=>{
  const admin=context('admin','admin@campus.test');
  const student=context('student','student@campus.test');
  const pending=context('pending','pending@campus.test');
  await assertSucceeds(setDoc(doc(admin,path('notices','notice-1')),
    {targetFacilityId:'',message:'Campus water update',createdBy:'admin',createdAt:time}));
  await assertSucceeds(getDoc(doc(student,path('notices','notice-1'))));
  await assertFails(getDoc(doc(pending,path('notices','notice-1'))));
});

test('teacher portal can request academic/canteen water, never private hostel water', async () => {
  const teacher=context('teacher','teacher@campus.test');
  await assertSucceeds(setDoc(doc(teacher,path('requests','teacher-canteen')),
    {...waterRequest('teacher'),facilityId:'canteen-1',room:''}));
  await assertFails(setDoc(doc(teacher,path('requests','teacher-hostel')),
    {...waterRequest('teacher'),facilityId:'hostel-1',room:''}));
  await assertSucceeds(getDocs(query(collection(teacher,'campuses/main/requests'),
    where('requestedBy','==','teacher'))));
  await assertFails(getDoc(doc(teacher,path('requests','request-1'))));
});
test('student assigned to academic facilities can file water requests and SOS', async () => {
  const student=context('daystudent','daystudent@campus.test');
  await assertSucceeds(setDoc(doc(student,path('requests','day-canteen')),
    {...waterRequest('daystudent'),facilityId:'canteen-1',room:''}));
  await assertFails(setDoc(doc(student,path('requests','day-hostel')),
    {...waterRequest('daystudent'),facilityId:'hostel-1',room:''}));
  await assertSucceeds(setDoc(doc(student,path('sos','day-incident')),{
    facilityId:'canteen-1',floor:0,restroom:'Kitchen',detail:'Tap leaking near sink',
    createdBy:'daystudent',createdByName:'Student',
    status:'open',createdAt:time,resolvedAt:''
  }));
});
test('admin member portal can approve and assign roles; worker cannot', async () => {
  const admin=context('admin','admin@campus.test');
  const worker=context('worker','worker@campus.test');
  await assertSucceeds(getDocs(query(collection(admin,'users'),
    where('campusId','==','main'))));
  await assertFails(getDocs(collection(worker,'users')));
  await assertSucceeds(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'warden',facilityId:'hostel-1',room:'102'
  }));
  await assertFails(updateDoc(doc(worker,'users','student'),{
    approved:false
  }));
});
test('role restricted SOS feed and member details remain private', async () => {
  const teacher=context('teacher','teacher@campus.test');
  const warden=context('warden','warden@campus.test');
  const worker=context('worker','worker@campus.test');
  await assertFails(getDocs(collection(teacher,'campuses/main/sos')));
  await assertFails(getDocs(collection(warden,'campuses/main/sos')));
  await assertSucceeds(getDocs(collection(worker,'campuses/main/sos')));
  await assertFails(getDoc(doc(teacher,'users','student')));
  await assertSucceeds(getDoc(doc(teacher,'users','teacher')));
});

test('both protected admins have identical campus and member-management permissions', async () => {
  const admin1=context('admin','admin@campus.test');
  const admin2=context('admin2','admin2@campus.test');
  for (const db of [admin1,admin2]) {
    await assertSucceeds(getDocs(collection(db,'campuses/main/facilities')));
    await assertSucceeds(getDocs(collection(db,'campuses/main/tanks')));
    await assertSucceeds(getDocs(collection(db,'campuses/main/requests')));
    await assertSucceeds(getDocs(collection(db,'campuses/main/sos')));
    await assertSucceeds(getDocs(query(collection(db,'users'),
      where('campusId','==','main'))));
  }
  await assertSucceeds(updateDoc(doc(admin2,'users','pending'),{
    role:'teacher',approved:true,facilityId:'',room:''
  }));
  await assertSucceeds(setDoc(doc(admin2,path('facilities','hostel-new')),
    facility()));
});

test('neither co-admin can demote the other or promote a third administrator', async () => {
  const admin1=context('admin','admin@campus.test');
  const admin2=context('admin2','admin2@campus.test');
  await assertFails(updateDoc(doc(admin1,'users','admin2'),{approved:false}));
  await assertFails(updateDoc(doc(admin2,'users','admin'),{role:'worker'}));
  await assertFails(updateDoc(doc(admin1,'users','pending'),{
    role:'admin',approved:true,facilityId:'',room:''
  }));
  await assertFails(updateDoc(doc(admin2,'users','admin2'),{approved:false}));
});

test('email verification is required even AFTER an Admin approves a member',async()=>{
  const admin=context('admin','admin@campus.test');
  await assertSucceeds(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'student',facilityId:'hostel-1',room:'105'
  }));
  const unverified=context('pending','pending@campus.test',false);
  const verified=context('pending','pending@campus.test',true);
  await assertSucceeds(getDoc(doc(unverified,'users','pending')));
  await assertFails(getDoc(doc(unverified,path('facilities','hostel-1'))));
  await assertFails(setDoc(doc(unverified,path('requests','not-verified')),
    {...waterRequest('pending'),room:'105'}));
  await assertSucceeds(getDoc(doc(verified,path('facilities','hostel-1'))));
  await assertSucceeds(setDoc(doc(verified,path('requests','after-verified')),
    {...waterRequest('pending'),room:'105'}));
});

test('partial registration recovery cannot spoof identities or elevated privileges',async()=>{
  const user=context('recovery','recovery@campus.test',false);
  const valid={...profile('recovery@campus.test','student',false,''),
    room:''};
  await assertSucceeds(setDoc(doc(user,'users','recovery'),valid));
  await assertFails(setDoc(doc(user,'users','recovery'),{...valid,role:'admin'}));
  await assertFails(setDoc(doc(user,'users','other'),valid));
  await assertFails(setDoc(doc(user,'users','recovery-extra'),{...valid,
    isAdmin:true}));
  await assertFails(setDoc(doc(user,'users','recovery-identity'),{...valid,
    email:'someoneelse@campus.test'}));
});

test('registration profile rejects unexpected fields and invalid names',async()=>{
  const user=context('checkreg','checkreg@campus.test',false);
  const valid={...profile('checkreg@campus.test','student',false,''),
    room:''};
  await assertFails(setDoc(doc(user,'users','checkreg'),{...valid,
    isCampusOwner:true}));
  await assertFails(setDoc(doc(user,'users','checkreg'),{...valid,name:'X'}));
  await assertFails(setDoc(doc(user,'users','checkreg'),{...valid,createdAt:0}));
  await assertSucceeds(setDoc(doc(user,'users','checkreg'),valid));
});

test('both Admins can approve staff but cannot approve unassigned students or non-hostel wardens',async()=>{
  const admin1=context('admin','admin@campus.test');
  const admin2=context('admin2','admin2@campus.test');
  await assertFails(updateDoc(doc(admin1,'users','pending'),{
    approved:true,role:'student',facilityId:'',room:''
  }));
  await assertFails(updateDoc(doc(admin2,'users','pending'),{
    approved:true,role:'warden',facilityId:'canteen-1',room:''
  }));
  await assertSucceeds(updateDoc(doc(admin1,'users','pending'),{
    approved:true,role:'worker',facilityId:'',room:''
  }));
  await assertSucceeds(updateDoc(doc(admin2,'users','pending'),{
    approved:true,role:'warden',facilityId:'hostel-1',room:'105'
  }));
});

test('college staff may request academic or canteen water, but cannot view hostel requests', async () => {
  const db = context('staff', 'staff@campus.test');
  await assertSucceeds(setDoc(doc(db,path('requests','staff-campus')),
    {...waterRequest('staff'),facilityId:'canteen-1',room:''}));
  await assertSucceeds(setDoc(doc(db,path('requests','staff-academic')),
    {...waterRequest('staff'),facilityId:'canteen-1',room:'',activity:'Cooking'}));
  await assertFails(setDoc(doc(db,path('requests','staff-hostel')),
    {...waterRequest('staff'),facilityId:'hostel-1',room:''}));
  await assertFails(getDoc(doc(db,path('requests','request-1'))));
  await assertSucceeds(getDocs(query(collection(db,'campuses/main/requests'),
    where('requestedBy','==','staff'))));
  await assertFails(getDocs(collection(db,'campuses/main/requests')));
});

test('canteen, gardener and driver see only assigned site water requests', async () => {
  for (const [id,site,activity] of [
    ['canteen','canteen-1','Cooking'],
    ['gardener','garden-1','Garden irrigation'],
    ['driver','transport-1','Vehicle washing'],
  ]) {
    const db=context(id,id+'@campus.test');
    await assertSucceeds(setDoc(doc(db,path('requests',id+'-own')),
      {...waterRequest(id),facilityId:site,activity,room:''}));
    await assertFails(setDoc(doc(db,path('requests',id+'-cross')),
      {...waterRequest(id),facilityId:'hostel-1',room:''}));
    await assertFails(getDocs(query(collection(db,'campuses/main/requests'),
      where('facilityId','==',site))));
    await assertSucceeds(getDocs(query(collection(db,'campuses/main/requests'),
      where('requestedBy','==',id))));
    await assertFails(getDocs(collection(db,'campuses/main/requests')));
    await assertFails(getDoc(doc(db,path('requests','request-1'))));
    await assertFails(updateDoc(doc(db,path('requests',id+'-own')),{
      status:'approved',approvedLitres:12,approvedBy:id,reviewedAt:time
    }));
  }
});

test('canteen, gardener and driver may report SOS only within assigned site', async () => {
  for(const [id,site] of [
    ['canteen','canteen-1'],
    ['gardener','garden-1'],
    ['driver','transport-1'],
  ]){
    const db=context(id,id+'@campus.test');
    const alert={facilityId:site,floor:0,restroom:'Water point',
      detail:'Water pipe leakage at this facility',createdBy:id,createdByName:id,
      status:'open',createdAt:time,resolvedAt:''};
    await assertSucceeds(setDoc(doc(db,path('sos','sos-'+id)),alert));
    await assertFails(setDoc(doc(db,path('sos','fake-'+id)),
      {...alert,facilityId:'hostel-1'}));
    await assertFails(getDocs(collection(db,'campuses/main/sos')));
    await assertFails(updateDoc(doc(db,path('sos','sos-'+id)),
      {status:'resolved',resolvedAt:time,resolvedBy:id}));
    await assertFails(updateDoc(doc(db,'users',id),{
      role:'admin',approved:true
    }));
  }
});

test('both admins can assign canteen, gardener, driver and college staff safely', async()=>{
  for (const [adminId,role,site] of [
    ['admin','canteen','canteen-1'],
    ['admin2','gardener','garden-1'],
    ['admin','driver','transport-1'],
    ['admin2','staff',''],
  ]) {
    const db=context(adminId,adminId+'@campus.test');
    await assertSucceeds(updateDoc(doc(db,'users','pending'),{
      approved:true,role,facilityId:site,room:''
    }));
  }
  const admin=context('admin','admin@campus.test');
  await assertFails(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'gardener',facilityId:'hostel-1'
  }));
  await assertFails(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'driver',facilityId:'canteen-1'
  }));
  await assertFails(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'canteen',facilityId:'garden-1'
  }));
  await assertFails(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'gardener',facilityId:''
  }));
  await assertFails(updateDoc(doc(admin,'users','pending'),{
    approved:true,role:'admin'
  }));
});

test('notification device tokens and inbox are private to the account', async()=>{
  const student=context('student','student@campus.test');
  const other=context('second','second@campus.test');
  const pathToken='users/student/devices/phone-one';
  const sample={token:'abcdefghijabcdefghij1234567890',platform:'android',updatedAt:time};
  await assertSucceeds(setDoc(doc(student,pathToken),sample));
  await assertSucceeds(getDoc(doc(student,pathToken)));
  await assertFails(getDoc(doc(other,pathToken)));
  await assertFails(setDoc(doc(other,pathToken),sample));
  await assertFails(setDoc(doc(student,'users/second/devices/hacked'),sample));
  await assertFails(setDoc(doc(student,'users/student/inbox/hacked'),
      {title:'Spoof',description:'Forged notification'}));
  await env.withSecurityRulesDisabled(async(ctx)=>{
    await setDoc(doc(ctx.firestore(),'users/student/inbox/real'),
      {title:'Water request',description:'Your request has changed',createdAt:time});
  });
  await assertSucceeds(getDoc(doc(student,'users/student/inbox/real')));
  await assertFails(getDoc(doc(other,'users/student/inbox/real')));
  await assertFails(getDocs(collection(other,'users/student/inbox')));
});

test('notices addressed to one campus area cannot be read by another',async()=>{
  const admin=context('admin','admin@campus.test');
  await assertSucceeds(setDoc(doc(admin,path('notices','canteen-only')),
      {targetFacilityId:'canteen-1',message:'Canteen shift schedule',
       createdBy:'admin',createdAt:time}));
  const canteen=context('canteen','canteen@campus.test');
  const student=context('student','student@campus.test');
  const teacher=context('teacher','teacher@campus.test');
  await assertSucceeds(getDoc(doc(canteen,path('notices','canteen-only'))));
  await assertSucceeds(getDoc(doc(teacher,path('notices','canteen-only'))));
  await assertFails(getDoc(doc(student,path('notices','canteen-only'))));
  await assertFails(getDocs(collection(student,'campuses/main/notices')));
  await assertSucceeds(getDocs(query(collection(student,'campuses/main/notices'),
      where('targetFacilityId','==',''))));
});
test('incident reporter reads only their SOS and cannot read other students',async()=>{
  const student=context('student','student@campus.test');
  const other=context('second','second@campus.test');
  const worker=context('worker','worker@campus.test');
  await assertSucceeds(setDoc(doc(student,path('sos','own-incident')),{
    facilityId:'hostel-1',floor:1,restroom:'Restroom 1',
    detail:'Water leakage requiring repairs',createdBy:'student',
    createdByName:'Student',status:'open',createdAt:time,resolvedAt:''
  }));
  await assertSucceeds(getDocs(query(collection(student,'campuses/main/sos'),
      where('createdBy','==','student'))));
  await assertFails(getDocs(collection(student,'campuses/main/sos')));
  await assertFails(getDoc(doc(other,path('sos','own-incident'))));
  await assertSucceeds(getDoc(doc(worker,path('sos','own-incident'))));
});
test('same-hostel students cannot access each others water submissions',async()=>{
  const student=context('student','student@campus.test');
  const second=context('second','second@campus.test');
  const warden=context('warden','warden@campus.test');
  await assertFails(getDoc(doc(second,path('requests','request-1'))));
  await assertFails(getDoc(doc(warden,path('requests','request-1'))));
  await assertSucceeds(getDoc(doc(student,path('requests','request-1'))));
});

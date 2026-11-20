'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const {endpoint, sample} = require('./activity');
test('private endpoint rejects credentials, cleartext and wrong paths', () => {
  assert.equal(endpoint('http://127.0.0.1:8787/v1/events/coding'), 'http://127.0.0.1:8787/v1/events/coding');
  for (const url of ['http://example.com/v1/events/coding', 'https://secret@example.com/v1/events/coding', 'https://example.com/wrong']) assert.throws(() => endpoint(url));
});
test('only active, focused, trusted minutes are counted; no source fields', () => {
  const state = {now: 120000, previous: 60000, lastEdit: 119000, focused: true, trusted: true, project: 'Test project'};
  assert.equal(sample(state).minutes, 1);
  assert.deepEqual(Object.keys(sample(state)).sort(), ['id', 'kind', 'project', 'timestamp', 'start', 'end', 'minutes'].sort());
  for (const patch of [{focused:false}, {trusted:false}, {lastEdit:0}, {previous:0}, {project:''}]) assert.equal(sample({...state, ...patch}), null);
});
const {EvidenceQueue}=require('./queue');
test('offline retry preserves IDs, bounded queue reports discarded backlog',async()=>{
  let saved=[],online=false,sent=[];
  const q=new EvidenceQueue({limit:2,persist:async x=>{saved=x;},send:async e=>{sent.push(e.id);return online;}});
  await q.add({id:'one'});await q.add({id:'two'});await q.add({id:'three'});
  assert.equal(q.dropped,1);await q.flush();assert.deepEqual(saved.map(x=>x.id),['two','three']);
  online=true;await q.flush();assert.deepEqual(sent,['two','two','three']);assert.equal(saved.length,0);
});
test('stop and erase cancel in-flight sends without resurrecting private records',async()=>{
  let resolve,saved=[];
  const q=new EvidenceQueue({events:[{id:'old'}],persist:async x=>{saved=x;},send:(_,signal)=>new Promise(r=>{resolve=r;signal.addEventListener('abort',()=>r(false));})});
  const delivery=q.flush();await q.erase();resolve(true);await delivery;
  assert.equal(q.events.length,0);assert.equal(saved.length,0);
  await q.add({id:'new'});assert.equal(saved[0].id,'new');
});

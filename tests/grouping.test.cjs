const {test} = require('node:test');
const assert = require('node:assert/strict');
const {groups, flatRows, keysForDismissal} = require('../Grouping.js');
const entries = [
 {key:'a',app:'Mail',timestamp:100,summary:'Old',urgency:2},
 {key:'b',app:'Chat',timestamp:200,body:'find me'},
 {key:'c',app:' mail ',timestamp:300,summary:'Newest'},
 {key:'d',app:'__proto__',timestamp:50},
];
test('application grouping is stable, recent first, retains hidden urgency and unread count',()=>{
 const g=groups(entries,'',150);
 assert.deepEqual(g.map(x=>x.key),['mail','chat','__proto__']);
 assert.deepEqual(g[0].entries.map(x=>x.key),['c','a']);
 assert.equal(g[0].urgent,true); assert.equal(g[0].unread,1);
});
test('collapsed groups preview latest; expanding reveals older messages',()=>{
 assert.equal(flatRows(entries,'',0,{},true).length,3);
 const rows=flatRows(entries,'',0,{mail:true},true);
 assert.equal(rows.length,5); assert.equal(rows[2].key,'a');
});
test('search includes older folded messages and ignores saved collapsed state',()=>{
 const rows=flatRows(entries,'old',0,{mail:false},true);
 assert.equal(rows.length,1); assert.equal(rows[0].key,'a');
 assert.equal(rows[0].expanded,true);
 assert.equal(groups(entries,'FIND ME',0)[0].key,'chat');
 assert.equal(groups(entries,'missing',0).length,0);
});
test('empty input and default expanded mode',()=>{
 assert.deepEqual(groups([],'',0),[]);
 assert.equal(flatRows(entries,'',0,{},false).length,5);
});

test('folded stack becomes an expanded header without losing keyboard selection',()=>{
 const folded=flatRows(entries,'',0,{},true);
 assert.equal(folded[0].header,false); assert.equal(folded[0].stacked,true);
 assert.equal(folded[0].groupCount,2);
 const expanded=flatRows(entries,'',0,{mail:true},true);
 assert.equal(expanded[0].header,true); assert.equal(expanded[0].stacked,false);
 assert.equal(folded[0].cursorKey,expanded[0].cursorKey);
 assert.equal(expanded[1].stacked,false);
});
test('single notifications never have a group header or stack',()=>{
 for (const collapsed of [true,false]) {
   const rows=flatRows([entries[1]],'',0,{},collapsed);
   assert.equal(rows.length,1); assert.equal(rows[0].header,false); assert.equal(rows[0].stacked,false);
 }
});
test('dismiss folded stack or header removes group; expanded card removes only itself',()=>{
 const folded=flatRows(entries,'',0,{},true);
 const expanded=flatRows(entries,'',0,{mail:true},true);
 assert.deepEqual(keysForDismissal(entries,folded[0],''),['c','a']);
 assert.deepEqual(keysForDismissal(entries,expanded[0],''),['c','a']);
 assert.deepEqual(keysForDismissal(entries,expanded[1],''),['c']);
 const searched=flatRows(entries,'old',0,{},true);
 assert.deepEqual(keysForDismissal(entries,searched[0],'old'),['a']);
});
test('removing the penultimate message leaves an ordinary single card',()=>{
 const rows=flatRows(entries.filter(e=>e.key!=='a'),'',0,{mail:true},true);
 assert.equal(rows[0].key,'c'); assert.equal(rows[0].header,false);
 assert.equal(rows[0].stacked,false); assert.equal(rows[0].groupCount,1);
});

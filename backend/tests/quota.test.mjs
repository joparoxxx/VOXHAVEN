import test from "node:test";
import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {DatabaseSync} from "node:sqlite";
import {quotaPlan} from "../src/policy.mjs";

// Exercise actual Quota SQL and transactions in Node; this is not a Workers runtime test.
const policyUrl=new URL("../src/policy.mjs",import.meta.url).href;
const source=(await readFile(new URL("../src/index.mjs",import.meta.url),"utf8"))
  .replace('import { DurableObject } from "cloudflare:workers";','class DurableObject { constructor() {} }')
  .replace('"./policy.mjs"',JSON.stringify(policyUrl));
const {Quota}=await import("data:text/javascript;base64,"+Buffer.from(source).toString("base64"));
function fixture(t,env={}){
  const db=new DatabaseSync(":memory:");
  t.after(()=>db.close());
  const storage={sql:{exec(query,...args){
    const stmt=db.prepare(query);
    return {toArray:()=>stmt.all(...args),...(/^SELECT\b/i.test(query)?{}:(stmt.run(...args),{}))};
  }},transactionSync(fn){
    db.exec("BEGIN");
    try{const r=fn();db.exec("COMMIT");return r;}catch(e){db.exec("ROLLBACK");throw e;}
  }};
  const quota=new Quota({storage},{});
  let id=0;
  async function call(path,body){
    const r=await quota.fetch(new Request("https://quota.internal/"+path,{method:"POST",body:JSON.stringify(body)}));
    return {status:r.status,...await r.json()};
  }
  async function reserve(uid="a",rpm=10){
    const lease="lease-"+(++id);
    const plan=quotaPlan("chat",uid,"ip",env);
    plan.push(["chat:attempt:user:"+uid,Number(env.DAILY_USER_ATTEMPTS??30)]);
    const result=await call("reserve",{kind:"chat",uid,lease,plan,cooldown:10,rpm});
    return {...result,uid,lease};
  }
  const release=(r,success)=>call("release",{uid:r.uid,lease:r.lease,day:r.day,cooldown:10,success});
  const expire=uid=>db.prepare("UPDATE chat_state SET until_ms=0 WHERE uid=?").run(uid);
  const count=k=>Number(db.prepare("SELECT n FROM usage WHERE k=?").get(k)?.n||0);
  return {reserve,release,expire,count};
}
test("one in-flight request, cooldown, failed refund and attempt retention",async t=>{
  const f=fixture(t,{DAILY_USER_REQUESTS:"2"});
  const a=await f.reserve();
  assert.equal(a.status,200);assert.equal(a.remaining,1);
  assert.equal((await f.reserve()).error,"CHAT_IN_PROGRESS");
  assert.equal((await f.release(a,false)).status,200);
  assert.equal(f.count("chat:user:a"),0);
  assert.equal(f.count("chat:global"),1);
  assert.equal(f.count("chat:attempt:user:a"),1);
  assert.equal(f.count("chat:failed"),1);
  assert.equal((await f.release(a,false)).status,409);
  assert.equal((await f.reserve()).error,"CHAT_COOLDOWN");
  f.expire("a");
  const b=await f.reserve();
  assert.equal(b.remaining,1);
  await f.release(b,true);
  assert.equal(f.count("chat:user:a"),1);
  assert.equal(f.count("chat:success"),1);
});
test("failed responses cannot bypass global and player attempt caps",async t=>{
  const f=fixture(t,{DAILY_GLOBAL_REQUESTS:"2",DAILY_USER_ATTEMPTS:"1"});
  const a=await f.reserve("a");await f.release(a,false);f.expire("a");
  assert.equal((await f.reserve("a")).error,"DAILY_LIMIT");
  const b=await f.reserve("b");await f.release(b,false);
  assert.equal((await f.reserve("c")).error,"DAILY_LIMIT");
  assert.equal(f.count("chat:global"),2);
});
test("rolling minute cap shared across users",async t=>{
  const f=fixture(t);
  const a=await f.reserve("a",1);assert.equal(a.status,200);
  const b=await f.reserve("b",1);assert.equal(b.error,"GLOBAL_RATE_LIMIT");
  assert.equal(f.count("chat:global"),1);
});

import test from "node:test";
import assert from "node:assert/strict";
import {limit, chatInput, claimsValid, quotaPlan} from "../src/policy.mjs";
test("fail closed for malformed limits",()=>{assert.equal(limit("bad",10,100),0);assert.equal(limit("0",10,100),0);assert.equal(limit("",10,100),10);});
test("bounded chat and fixed cubot IDs",()=>{assert.ok(chatInput({cubot:"atlas",prompt:"hello",system:"context"}));assert.equal(chatInput({cubot:"x",prompt:"hello",system:""}),null);assert.equal(chatInput({cubot:"atlas",prompt:"a".repeat(2049),system:""}),null);});
test("Firebase claims require correct project and expiry",()=>{const c={aud:"p",iss:"https://securetoken.google.com/p",sub:"u",exp:101,iat:90,auth_time:90,firebase:{sign_in_provider:"anonymous"}};assert.ok(claimsValid(c,"p",100));assert.equal(claimsValid(c,"q",100),false);assert.equal(claimsValid(c,"p",101),false);});
test("global cap is shared across users",()=>{assert.equal(quotaPlan("chat","a","ip",{})[0][0],quotaPlan("chat","b","ip",{})[0][0]);assert.equal(quotaPlan("chat","a","ip",{DAILY_GLOBAL_REQUESTS:"0"})[0][1],0);});

test("guest signup cap is configurable and bounded independently of chat",()=>{assert.equal(quotaPlan("guest","","ip",{})[1][1],5);assert.equal(quotaPlan("guest","","ip",{DAILY_GUEST_IP_REQUESTS:"10"})[1][1],10);assert.equal(quotaPlan("guest","","ip",{DAILY_GUEST_IP_REQUESTS:"21"})[1][1],0);assert.equal(quotaPlan("refresh","","ip",{DAILY_GUEST_IP_REQUESTS:"10"})[1][1],30);});

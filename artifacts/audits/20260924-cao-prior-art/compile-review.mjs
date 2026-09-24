import { readFileSync, writeFileSync } from 'node:fs';
import { compilePlan, planHash } from 'file:///C:/Users/jleyv/Peanut%20Butter/Marshmallow%20Meta%20Commons/codex/skills/field-test/scripts/compile-plan.mjs';
const dir = new URL('./', import.meta.url);
const plan = JSON.parse(readFileSync(new URL('field-test-plan-v2.json', dir), 'utf8'));
const invocation = compilePlan(plan, {host:'codex',sessionId:'01a0b758-3c1e-7522-92f4-31ae4ea1ffe3',invocationId:'sao-enacted-social-work-002'});
writeFileSync(new URL('field-test-invocation-v2.json', dir), JSON.stringify(invocation,null,2)+'\n', {flag:'wx'});
console.log(JSON.stringify({planSha256:planHash(plan),submitted:false}));

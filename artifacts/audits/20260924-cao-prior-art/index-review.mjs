import { MousecatClient } from 'file:///C:/Users/jleyv/Peanut%20Butter/AI%20Assisted%20Software%20Engineering%20Mass%20Repository/Projects/Open%20Source/Mousecat/src/sdk/client.mjs';
const client=new MousecatClient({endpoint:'http://127.0.0.1:4317/mcp'});
for (const file of ['IMPLEMENTATION_SPEC.md','GOVERNANCE_AND_ML_PLAN.md','REVIEW.md']) {
 const result=await client.callTool('mousecat.history',{action:'index',surfaceId:'sao-social-work-plan',path:'artifacts/audits/20260924-cao-prior-art/'+file,permit:{profileId:'operator-interaction'}});
 console.log(JSON.stringify({file,result}));
}

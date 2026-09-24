import { chromium } from 'file:///C:/Users/jleyv/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const url=process.argv[2];
const browser=await chromium.launch({channel:'msedge',headless:true});
const results=[];
try {
 for (const [name,width,height] of [['desktop',1440,1000],['narrow',430,932]]) {
  const context=await browser.newContext({viewport:{width,height}});
  const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url,{waitUntil:'networkidle'});
  await page.getByText('Make social decisions produce real shared work',{exact:true}).first().waitFor();
  await page.screenshot({path:fileURLToPath(new URL('review-'+name+'.png',import.meta.url)),fullPage:true});
  const layout=await page.evaluate(()=>({width:innerWidth,documentWidth:document.documentElement.scrollWidth,details:[...document.querySelectorAll('details')].map(e=>({title:e.querySelector('summary')?.textContent,open:e.open})),links:[...document.querySelectorAll('a')].filter(e=>e.getAttribute('href')?.includes('sao-social-work-plan')).map(e=>({text:e.textContent,href:e.getAttribute('href')}))}));
  await page.getByText('Revise this plan',{exact:true}).last().scrollIntoViewIfNeeded();
  await page.screenshot({path:fileURLToPath(new URL('review-'+name+'-controls.png',import.meta.url)),fullPage:true});
  const sourceResults=[];
  for (const link of layout.links) {
   const ref=new URLSearchParams(link.href.split('?')[1]).get('ref');
   const response=await page.request.get('http://127.0.0.1:4317/api/history?'+new URLSearchParams({ref}));
   const data=await response.json();
   if(response.status()!==200 || data.ok!==true) throw new Error('Unresolved source: '+link.text);
   sourceResults.push({label:link.text,status:response.status(),ok:data.ok,keys:Object.keys(data),resolved:JSON.stringify(data).includes('source-record')});
  }
  await page.getByText('Supporting evidence',{exact:true}).click();
  await page.getByRole('link',{name:'Detailed specification',exact:true}).click();
  await page.locator('#history-dialog').waitFor({state:'visible'});
  await page.waitForFunction(()=>document.querySelector('#history-dialog')?.textContent.includes('Enacted social decisions and character continuity'));
  await page.screenshot({path:fileURLToPath(new URL('review-'+name+'-source.png',import.meta.url)),fullPage:true});
  results.push({name,url,errors,...layout,sourceResults,sourceDialogVisible:true});
  await context.close();
 }
 writeFileSync(new URL('presentation-check.json',import.meta.url),JSON.stringify({mode:'headless isolated browser; no operator UI input or response',results},null,2)+'\n');
 console.log(JSON.stringify(results));
} finally { await browser.close(); }

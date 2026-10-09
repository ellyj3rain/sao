"""Focused production readiness races, source custody controls and optional read-only UIA evidence."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];TOOLS=ROOT/'tools'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);parser.add_argument('--desktop-evidence',action='store_true');args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 helper=TOOLS/'world_lab_open_mousecat.ps1';fixture=TOOLS/'world_lab_mousecat_readiness_cases.ps1';originalFixture=TOOLS/'world_lab_open_mousecat_cases.ps1';native=TOOLS/'world_lab_mousecat_readonly.ps1'
 failed=Path('C:/Users/jleyv/AppData/Local/Temp/sao-d2-owned-leisure-live03-20261006-055900Z/session/mousecat-selection.json');registry=ROOT.parents[1]/'survivor-awareness/_scratch/c87-study/desktop-bindings.json'
 inputs=[Path(__file__),helper,fixture,originalFixture,native];pins={str(p):sha(p)for p in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,caseHelper,caseFixture,marker=None,extra=()):
  command=['powershell.exe','-NoProfile','-NonInteractive','-File',str(caseFixture),'-Helper',str(caseHelper),*extra];result=subprocess.run(command,capture_output=True,text=True,timeout=40,cwd=ROOT);log=out/(name+'.log');log.write_text(result.stdout+result.stderr);text=log.read_text();assert(result.returncode!=0 and marker in text)if marker else(result.returncode==0 and'PASS'in text),text
  receipt['runs'].append({'name':name,'exit':result.returncode,'expectedFailure':marker,'logSha256':sha(log)});save()
 try:
  run('readiness-production',helper,fixture);run('existing-source-binding17',helper,originalFixture)
  source=helper.read_text();prefix=fixture.read_text().split("Reset @((State 'Exact source' $true))",1)[0]
  isolated=out/'auto-follow-empty.ps1';isolated.write_text(prefix+"\nReset @((State 'Earlier'),(State 'Earlier'),(State 'Exact source'),(State 'Exact source' $true))\ntry{$result=Complete-DesktopSelection $null $request $owners}catch{throw \"MOUSECAT_READINESS:auto_follow_during_empty_popup_no_invocation rejected: $($_.Exception.Message)\"}\nCheck 'auto_follow_during_empty_popup_no_invocation' (-not $result.selected -and $script:invocations -eq 0)\nWrite-Output 'PASS auto-follow empty popup'\n")
  variants=[('restored-missing-readiness', [('if($state.value -ceq $Request.Label){','if($state.value -ceq $Request.Label -and $attempt -eq 0){')],isolated,'auto_follow_during_empty_popup_no_invocation'),
    ('restored-missing-postscan-requery',[('if($ready.value -ceq $Request.Label){$targetSeen=$true}','if($false){$targetSeen=$true}')],fixture,'auto_follow_after_scan_not_invoked'),
    ('restored-foreign-option-admission',[('$Owners.Contains([int]$Option.Current.ProcessId)','$true')],fixture,'foreign_popup_excluded'),
    ('restored-operator-navigation-guards',[("elseif(($targetSeen -and $state.value) -or\n                ($state.value -and $initialValue -and $state.value -cne $initialValue)){","elseif($false){"),("elseif($ready.value -and $initialValue -and $ready.value -cne $initialValue){","elseif($false){"),("elseif($invokeReady.value -and $initialValue -and $invokeReady.value -cne $initialValue){","elseif($false){")],fixture,'operator_changed_choice_before_popup')]
  variants.extend([
    ('restored-offscreen-no-scroll',[('$scrolled=Scroll-SelectionOption $candidates[0] $Request $Owners','$scrolled=$false')],fixture,'unique_offscreen_scroll_then_one_visible_invoke'),
    ('restored-unbounded-scroll',[('and -not $scrollAttempted){','and $true){')],fixture,'offscreen_one_scroll_only'),
    ('restored-offscreen-invocation',[('$candidates | Where-Object {Test-SelectionOption $_ $Request $Owners}','$candidates | Where-Object {$true}')],fixture,'unique_offscreen_scroll_then_one_visible_invoke')])
  variants.extend([
    ('restored-typed-path-omission',[('if(Test-SelectionTypedOption $candidates[0] $Request $Owners){','if($false){')],fixture,'typed_exact_offscreen_once'),
    ('restored-typed-source-guard',[('if(-not (Test-SelectionSnapshot $Request $fresh) -or\n        $fresh.binding.bindingId -cne $Request.SelectionBindingId){','if($false){')],fixture,'typed_production_refuses_foreign-session')])
  visibleOnly=out/'visible-source-only.ps1';visibleOnly.write_text(prefix+"\nReset @((State 'Earlier')) @((Option));$script:sourceCurrent=$false\nRefused 'visible_stale_source_refused' '*live source changed*'\nCheck 'visible_stale_zero_invoke' ($script:invocations -eq 0)\nWrite-Output 'PASS visible source isolation'\n")
  visibleOptionOnly=out/'visible-option-only.ps1';visibleOptionOnly.write_text(prefix+"\nReset @((State 'Earlier')) @((Option));$script:visibleOptionsAfterQuery=@()\nRefused 'visible_option_lost_after_query' '*option changed*'\nCheck 'visible_lost_zero_invoke' ($script:invocations -eq 0)\nWrite-Output 'PASS visible option isolation'\n")
  variants.extend([
    ('restored-visible-source-guard', [('Confirm-SelectionSource $Request\n                        $invokeReady=', '$invokeReady=')], visibleOnly,'visible_stale_source_refused'),
    ('restored-visible-ui-navigation', [('if(-not $invokeReady.selectorVisible -or -not $Owners.Contains([int]$invokeReady.selector.Current.ProcessId) -or\n                            ($invokeReady.value -and $invokeReady.value -cne $Request.Label -and -not $invokeReady.currentHeadingVisible)){','if($false){')], fixture,'visible_navigation_zero_invoke'),
    ('restored-visible-option-requery', [('$invokeCandidates=@(Read-SelectionOptions $Request $Owners -IncludeOffscreen)','$invokeCandidates=$options')], visibleOptionOnly,'visible_option_lost_after_query'),
    ('restored-source-hwnd-guard', [(' -or\n        [long]$desktop.MainWindowHandle -ne $Request.SelectionDesktopHwnd','')], fixture,'typed_production_refuses_desktop-hwnd')])
  for name,changes,cases,marker in variants:
   broken=source
   for before,after in changes:assert broken.count(before)==1;broken=broken.replace(before,after,1)
   path=out/(name+'.ps1');path.write_text(broken);run(name,path,cases,'MOUSECAT_READINESS:'+marker)
  if args.desktop_evidence:
   assert failed.is_file() and registry.is_file();beforeFailed=sha(failed);beforeRegistry=sha(registry);(out/'original-failed-selection.json').write_bytes(failed.read_bytes())
   run('native-readonly',helper,native,extra=('-OriginalReceipt',str(failed),'-Registry',str(registry),'-Output',str(out/'native-readonly.json')))
   assert sha(failed)==beforeFailed and sha(registry)==beforeRegistry
   observed=json.loads((out/'native-readonly.json').read_text());assert observed['status']=='PASS' and observed['selectionPerformed']is False and observed['mutationsAllowed']is False
   assert observed['desktopPid']==18256 and observed['label']=='Rosewood D2 integrated leisure live 03'
   assert observed['connection']!='live' and observed['liveAcceptance']is False
   receipt['nativeReadOnly']={'receiptSha256':sha(out/'native-readonly.json'),'originalFailureSha256':beforeFailed,'registrySha256':beforeRegistry,'desktopPid':observed['desktopPid'],'connection':observed['connection'],'state':observed['state'],'staleSourceRefused':True}
  receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==pins
  readinessCount=int(re.search(r'PASS Mousecat readiness (\d+)',(out/'readiness-production.log').read_text()).group(1))
  receipt.update(status='PASS',controlledReadinessChecks=readinessCount,existingBindingChecks=17,restoredControls=len(variants),selectionAttemptsBounded=1,historicalRaceUnproven=True);save();print(f'PASS readiness{readinessCount}/source-binding17/restored{len(variants)}'+('; native evidence read-only'if args.desktop_evidence else''))
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()

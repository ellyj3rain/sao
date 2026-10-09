param([Parameter(Mandatory=$true)][string]$Helper)
$ErrorActionPreference='Stop'
. $Helper
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$script:checks=0
$sourceScroll=(Get-Command Scroll-SelectionOption).ScriptBlock
$sourceConfirm=(Get-Command Confirm-SelectionSource).ScriptBlock
function Check($Name,$Ok){if(-not $Ok){throw "MOUSECAT_READINESS:$Name"};$script:checks++}
$request=@{Label='Exact source'}
$owners=[Collections.Generic.HashSet[int]]::new();[void]$owners.Add(77)
function State($Value,$Heading=$false,$Visible=$true,$ElementProcessId=77,$CurrentHeading=$true){return @{currentHeadingVisible=$CurrentHeading;value=$Value;headingVisible=$Heading;selectorVisible=$Visible;selector=[pscustomobject]@{Current=[pscustomobject]@{ProcessId=$ElementProcessId}}}}
function Option($Name='Exact source',$ElementProcessId=77,$Hidden=$false,$Enabled=$true,$Invokable=$true,$Scrollable=$true,$Typed=$false,$Kind=[System.Windows.Automation.ControlType]::ListItem){
    $row=[pscustomobject]@{Current=[pscustomobject]@{Name=$Name;ProcessId=$ElementProcessId;IsOffscreen=$Hidden;IsEnabled=$Enabled;ControlType=$Kind};Invokable=$Invokable;Scrollable=$Scrollable;Typed=$Typed}
    $row | Add-Member -MemberType ScriptMethod -Name GetCurrentPropertyValue -Value {param($Property);if($Property -eq [System.Windows.Automation.AutomationElement]::IsSelectionItemPatternAvailableProperty){return $this.Typed};if($Property -eq [System.Windows.Automation.AutomationElement]::IsScrollItemPatternAvailableProperty){return $this.Scrollable};return $this.Invokable}
    return $row
}
function Reset($States,$Options=@()){
    $script:states=@($States);$script:cursor=0;$script:options=@($Options | ForEach-Object {if($_ -is [string]){Option}else{$_}})
    $script:invocations=0;$script:opens=0;$script:closes=0;$script:scans=0;$script:scrolls=0;$script:keepHidden=$false;$script:typedSelections=0;$script:sourceConfirms=0;$script:sourceCurrent=$true;$script:typedFault=$false;$script:typedOptionsChanged=$false;$script:visibleOptionsAfterQuery=$null;$script:invokeFault=$false
}
function Read-SelectionUiState($Root,$Request){$at=[Math]::Min($script:cursor,$script:states.Count-1);$script:cursor++;return $script:states[$at]}
function Read-SelectionOptions($Request,$Owners,[switch]$IncludeOffscreen){$script:scans++;if($script:typedOptionsChanged -and $script:scans -gt 1){return @()};if($null -ne $script:visibleOptionsAfterQuery -and $script:scans -gt 1){return $script:visibleOptionsAfterQuery};return $script:options}
function Open-SelectionPopup($Selector){$script:opens++;return 'controlled-popup'}
function Close-SelectionPopup($Expand){if($null -ne $Expand){$script:closes++}}
function Invoke-SelectionOption($Option){$script:invocations++;if($script:invokeFault){throw 'Visible provider failure'}}
function Scroll-SelectionOption($Option,$Request,$Owners){
    if(-not (Test-SelectionOption $Option $Request $Owners -IncludeOffscreen) -or -not $Option.Scrollable){return $false}
    $script:scrolls++;if(-not $script:keepHidden){$Option.Current.IsOffscreen=$false};return $true
}
function Confirm-SelectionSource($Request){$script:sourceConfirms++;if(-not $script:sourceCurrent){throw 'Exact live source changed before typed selection'}}
function Apply-SelectionItem($Option){$script:typedSelections++;if($script:typedFault){throw 'Typed provider failure'}}
function Start-Sleep {param($Milliseconds)}
function Refused($Name,$Reason){try{$null=Complete-DesktopSelection $null $request $owners;throw 'unexpected success'}catch{Check $Name ($_.Exception.Message -like $Reason)}}
Reset @((State 'Exact source' $true))
$result=Complete-DesktopSelection $null $request $owners
Check 'already_ready_zero_mutations' ($result.visible -and -not $result.selected -and $script:invocations -eq 0 -and $script:opens -eq 0)
Reset @((State 'Exact source'),(State 'Exact source'),(State 'Exact source' $true))
$result=Complete-DesktopSelection $null $request $owners
Check 'chosen_heading_delayed_no_popup' (-not $result.selected -and $script:opens -eq 0 -and $script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Exact source'),(State 'Exact source' $true))
try{$result=Complete-DesktopSelection $null $request $owners}catch{throw "MOUSECAT_READINESS:auto_follow_during_empty_popup_no_invocation rejected: $($_.Exception.Message)"}
Check 'auto_follow_during_empty_popup_no_invocation' (-not $result.selected -and $script:opens -eq 1 -and $script:scans -eq 1 -and $script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Exact source'),(State 'Exact source' $true)) @('target')
try{$result=Complete-DesktopSelection $null $request $owners}catch{throw "MOUSECAT_READINESS:auto_follow_after_scan_not_invoked rejected: $($_.Exception.Message)"}
Check 'auto_follow_after_scan_not_invoked' (-not $result.selected -and $script:scans -eq 1 -and $script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source'),(State 'Exact source' $true)) @('target')
$result=Complete-DesktopSelection $null $request $owners
Check 'one_invocation_then_async_heading' ($result.selected -and $script:invocations -eq 1 -and $script:scans -eq 2 -and $script:sourceConfirms -eq 1)
Reset @((State 'Earlier'),(State 'Different operator choice')) @('target')
Refused 'operator_changed_choice_before_popup' '*choice changed*'
Check 'operator_choice_no_invocation' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Different operator choice')) @('target')
Refused 'operator_changed_during_scan' '*choice changed*'
Check 'operator_scan_no_invocation' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source'),(State 'Different operator choice')) @('target')
Refused 'operator_changed_after_invocation' '*choice changed*'
Check 'operator_postinvoke_never_reselected' ($script:invocations -eq 1)
Reset @((State 'Earlier'),(State 'Earlier' $false $false))
Refused 'operator_left_simulation' '*navigation changed*'
Reset @((State 'Earlier'),(State 'Earlier' $false $true 999))
Refused 'foreign_selector_process' '*process changed*'
Reset @((State 'Earlier')) @('target','duplicate')
Refused 'ambiguous_popup_refused' '*ambiguously available*'
Check 'ambiguous_zero_invocations' ($script:invocations -eq 0)
Reset @((State 'Earlier'))
Refused 'missing_popup_diagnostic_count' '*visible invokable matches=0'
Reset @((State 'Exact source'))
Refused 'target_without_heading_not_success' '*heading was not visible*'
Check 'target_without_heading_no_invocation' ($script:invocations -eq 0 -and $script:opens -eq 0)
Check 'visible_exact_owned_option' (Test-SelectionOption (Option) $request $owners)
Check 'foreign_popup_excluded' (-not (Test-SelectionOption (Option 'Exact source' 999) $request $owners))
Check 'hidden_popup_excluded' (-not (Test-SelectionOption (Option 'Exact source' 77 $true) $request $owners))
Check 'disabled_popup_excluded' (-not (Test-SelectionOption (Option 'Exact source' 77 $false $false) $request $owners))
Check 'noninvokable_popup_excluded' (-not (Test-SelectionOption (Option 'Exact source' 77 $false $true $false) $request $owners))
Check 'wrong_label_excluded' (-not (Test-SelectionOption (Option 'Other source') $request $owners))
Check 'offscreen_candidate_exact_owned' (Test-SelectionOption (Option 'Exact source' 77 $true) $request $owners -IncludeOffscreen)
Check 'offscreen_candidate_foreign_refused' (-not (Test-SelectionOption (Option 'Exact source' 999 $true) $request $owners -IncludeOffscreen))
Check 'source_scroll_no_pattern_refused' (-not (& $sourceScroll (Option 'Exact source' 77 $true $true $true $false) $request $owners))
Check 'source_scroll_foreign_refused' (-not (& $sourceScroll (Option 'Exact source' 999 $true) $request $owners))
Check 'source_scroll_visible_refused' (-not (& $sourceScroll (Option) $request $owners))
$hidden=Option 'Exact source' 77 $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @($hidden)
try{$result=Complete-DesktopSelection $null $request $owners}catch{throw "MOUSECAT_READINESS:unique_offscreen_scroll_then_one_visible_invoke rejected: $($_.Exception.Message)"}
Check 'unique_offscreen_scroll_then_one_visible_invoke' ($result.selected -and $result.scrolled -and $script:scrolls -eq 1 -and $script:invocations -eq 1 -and $script:scans -eq 3 -and $script:sourceConfirms -eq 1)
$hidden=Option 'Exact source' 77 $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @($hidden)
$result=Complete-DesktopSelection $null $request $owners
Check 'auto_follow_after_scroll_zero_invoke' (-not $result.selected -and $script:scrolls -eq 1 -and $script:invocations -eq 0)
$hidden=Option 'Exact source' 77 $true
Reset @((State 'Earlier')) @($hidden);$script:keepHidden=$true
Refused 'still_offscreen_never_invoked' '*visible invokable matches=0'
Check 'offscreen_one_scroll_only' ($script:scrolls -eq 1 -and $script:invocations -eq 0)
$hidden=Option 'Exact source' 77 $true $true $true $false
Reset @((State 'Earlier')) @($hidden)
Refused 'missing_scroll_provider_refused' '*visible invokable matches=0'
Check 'missing_provider_no_effect' ($script:scrolls -eq 0 -and $script:invocations -eq 0)
$hidden=Option 'Exact source' 77 $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Different operator choice')) @($hidden)
Refused 'operator_changed_before_scroll_refused' '*choice changed*'
Check 'operator_pre_scroll_no_effect' ($script:scrolls -eq 0 -and $script:invocations -eq 0)
$hidden=Option 'Exact source' 77 $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Different operator choice')) @($hidden)
Refused 'operator_changed_after_scroll_refused' '*choice changed*'
Check 'operator_post_scroll_no_invoke' ($script:scrolls -eq 1 -and $script:invocations -eq 0)
Reset @((State 'Earlier')) @((Option),(Option 'Exact source' 77 $true))
Refused 'visible_plus_hidden_duplicate_refused' '*ambiguously available*'
Check 'duplicates_no_scroll_or_invoke' ($script:scrolls -eq 0 -and $script:invocations -eq 0)
$typed=Option 'Exact source' 77 $true $true $false $false $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @($typed)
try{$result=Complete-DesktopSelection $null $request $owners}catch{throw "MOUSECAT_READINESS:typed_exact_offscreen_once rejected: $($_.Exception.Message)"}
Check 'typed_exact_offscreen_once' ($result.selected -and $result.selectionMethod -eq 'SelectionItem' -and $script:typedSelections -eq 1 -and $script:invocations -eq 0 -and $script:scrolls -eq 0 -and $script:sourceConfirms -eq 1 -and $script:scans -eq 2)
$visibleTyped=Option 'Exact source' 77 $false $true $false $false $true
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @($visibleTyped)
$result=Complete-DesktopSelection $null $request $owners
Check 'typed_visible_noninvoke_uses_typed_provider' ($script:typedSelections -eq 1 -and $script:invocations -eq 0 -and $result.selectionMethod -eq 'SelectionItem')
Reset @((State 'Earlier')) @($typed);$script:sourceCurrent=$false
Refused 'typed_stale_source_refused' '*live source changed*'
Check 'typed_stale_source_zero_effect' ($script:typedSelections -eq 0 -and $script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Different operator choice')) @($typed)
Refused 'typed_operator_change_during_source_query' '*choice changed*'
Check 'typed_operator_change_zero_effect' ($script:typedSelections -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier' $false $false)) @($typed)
Refused 'typed_navigation_change_during_source_query' '*navigation changed*'
Check 'typed_navigation_change_zero_effect' ($script:typedSelections -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier' $false $true 77 $false)) @($typed)
Refused 'typed_original_heading_lost_refused' '*navigation changed*'
Check 'typed_original_heading_lost_zero_effect' ($script:typedSelections -eq 0)
Reset @((State 'Earlier')) @($typed);$script:typedFault=$true
Refused 'typed_provider_failure_no_retry' '*Typed provider failure*'
Check 'typed_provider_attempt_once' ($script:typedSelections -eq 1)
Reset @((State 'Earlier')) @($typed);$script:typedOptionsChanged=$true
Refused 'typed_lost_option_after_source_query' '*option changed*'
Check 'typed_lost_option_no_effect' ($script:typedSelections -eq 0)
Reset @((State 'Earlier')) @($typed,$typed)
Refused 'typed_duplicate_refused' '*ambiguously available*'
Check 'typed_duplicate_no_effect' ($script:typedSelections -eq 0)
Check 'typed_foreign_process_refused' (-not (Test-SelectionTypedOption (Option 'Exact source' 999 $true $true $false $false $true) $request $owners))
Check 'typed_disabled_refused' (-not (Test-SelectionTypedOption (Option 'Exact source' 77 $true $false $false $false $true) $request $owners))
Check 'typed_mistyped_control_refused' (-not (Test-SelectionTypedOption (Option 'Exact source' 77 $true $true $false $false $true ([System.Windows.Automation.ControlType]::Text)) $request $owners))
Check 'typed_provider_absent_refused' (-not (Test-SelectionTypedOption (Option 'Exact source' 77 $true $true $true $false $false) $request $owners))
# Exact visible Invoke must use the same source query before its final UI query.
Reset @((State 'Earlier')) @((Option));$script:sourceCurrent=$false
Refused 'visible_stale_source_refused' '*live source changed*'
Check 'visible_stale_zero_invoke' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Different operator choice')) @((Option))
Refused 'visible_operator_change_after_source_query' '*choice changed*'
Check 'visible_operator_change_zero_invoke' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier' $false $false)) @((Option))
Refused 'visible_navigation_after_source_query' '*navigation changed*'
Check 'visible_navigation_zero_invoke' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier' $false $true 77 $false)) @((Option))
Refused 'visible_original_heading_after_source_query' '*navigation changed*'
Check 'visible_heading_zero_invoke' ($script:invocations -eq 0)
Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @((Option))
$result=Complete-DesktopSelection $null $request $owners
Check 'visible_auto_follow_after_source_query_zero_invoke' ($result.visible -and -not $result.selected -and $script:invocations -eq 0 -and $script:sourceConfirms -eq 1)
foreach($mode in @('lost','disabled','hidden','foreign','wrong-label','duplicate')){
 Reset @((State 'Earlier')) @((Option))
 $script:visibleOptionsAfterQuery=@()
 if($mode -eq 'disabled'){$script:visibleOptionsAfterQuery=@((Option 'Exact source' 77 $false $false))}
 if($mode -eq 'hidden'){$script:visibleOptionsAfterQuery=@((Option 'Exact source' 77 $true))}
 if($mode -eq 'foreign'){$script:visibleOptionsAfterQuery=@((Option 'Exact source' 999))}
 if($mode -eq 'wrong-label'){$script:visibleOptionsAfterQuery=@((Option 'Other source'))}
 if($mode -eq 'duplicate'){$script:visibleOptionsAfterQuery=@((Option),(Option))}
 $expected=if($mode -eq 'duplicate'){'*ambiguously available*'}else{'*option changed*'}
 Refused ('visible_option_'+$mode+'_after_query') $expected
 Check ('visible_option_'+$mode+'_zero_invoke') ($script:invocations -eq 0)
}
Reset @((State 'Earlier')) @((Option));$script:invokeFault=$true
Refused 'visible_provider_fault_no_retry' '*Visible provider failure*'
Check 'visible_provider_fault_one_attempt' ($script:invocations -eq 1)
# Requery actual production live-source guard with explicit controlled native/API services.
$sourceRequest=@{ViewId='target';NativeSession='ab37c02c-b28a-4d36-bb52-51f57b999105';Label='Exact source';SelectionBindingId=('a'*64);SelectionDesktopPid=77;SelectionDesktopHwnd=2}
$script:guardDesktop=[pscustomobject]@{Id=77;MainWindowHandle=2}
$script:guardSnapshot=[pscustomobject]@{schema='mousecat.native-view-response/1';binding=[pscustomobject]@{id='target';label='Exact source';bindingId=('a'*64)};view=[pscustomobject]@{sessionId=$sourceRequest.NativeSession;state='running'};connection='live'}
function Get-SelectionDesktop{return $script:guardDesktop}
function Read-SelectionBinding($Request){if($script:bindingChanged){throw 'Target source binding differs'}}
function Read-SelectionSnapshot($Request){return $script:guardSnapshot}
$script:bindingChanged=$false
& $sourceConfirm $sourceRequest
Check 'typed_production_live_source_current' $true
foreach($mode in @('foreign-session','stale','binding-revision','desktop-family','desktop-hwnd','registry-rebind')){
 $script:guardSnapshot.view.sessionId=$sourceRequest.NativeSession;$script:guardSnapshot.connection='live';$script:guardSnapshot.binding.bindingId=('a'*64);$script:guardDesktop.Id=77;$script:guardDesktop.MainWindowHandle=2;$script:bindingChanged=$false
 if($mode -eq 'foreign-session'){$script:guardSnapshot.view.sessionId='fe5c89f6-54d1-40e8-84c8-d850d84a0410'}
 if($mode -eq 'stale'){$script:guardSnapshot.connection='stale'}
 if($mode -eq 'binding-revision'){$script:guardSnapshot.binding.bindingId=('b'*64)}
 if($mode -eq 'desktop-family'){$script:guardDesktop.Id=999}
 if($mode -eq 'desktop-hwnd'){$script:guardDesktop.MainWindowHandle=3}
 if($mode -eq 'registry-rebind'){$script:bindingChanged=$true}
 try{& $sourceConfirm $sourceRequest;throw 'unexpected source success'}catch{Check ('typed_production_refuses_'+$mode) ($_.Exception.Message -notlike 'unexpected source success')}
}
function Confirm-SelectionSource($Request){$script:sourceConfirms++;& $sourceConfirm $Request}
foreach($mode in @('foreign-session','stale','binding-revision','desktop-family','desktop-hwnd','registry-rebind')){
 $script:guardSnapshot.view.sessionId=$sourceRequest.NativeSession;$script:guardSnapshot.connection='live';$script:guardSnapshot.binding.bindingId=('a'*64);$script:guardDesktop.Id=77;$script:guardDesktop.MainWindowHandle=2;$script:bindingChanged=$false
 if($mode -eq 'foreign-session'){$script:guardSnapshot.view.sessionId='fe5c89f6-54d1-40e8-84c8-d850d84a0410'}
 if($mode -eq 'stale'){$script:guardSnapshot.connection='stale'}
 if($mode -eq 'binding-revision'){$script:guardSnapshot.binding.bindingId=('b'*64)}
 if($mode -eq 'desktop-family'){$script:guardDesktop.Id=999}
 if($mode -eq 'desktop-hwnd'){$script:guardDesktop.MainWindowHandle=3}
 if($mode -eq 'registry-rebind'){$script:bindingChanged=$true}
 Reset @((State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Earlier'),(State 'Exact source' $true)) @((Option))
 try{$null=Complete-DesktopSelection $null $sourceRequest $owners;throw 'unexpected source success'}catch{Check ('visible_production_refuses_'+$mode) ($_.Exception.Message -notlike 'unexpected source success')}
 Check ('visible_production_'+$mode+'_zero_effect') ($script:invocations -eq 0)
}
Write-Output "PASS Mousecat readiness $script:checks"

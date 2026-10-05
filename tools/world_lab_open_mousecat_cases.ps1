param([Parameter(Mandatory=$true)][string]$Helper)
$ErrorActionPreference='Stop'
. $Helper
$checks=0
function Check($Name,$Value){if(-not $Value){throw "OPEN_MOUSECAT:$Name"};$script:checks++}
$directory=Join-Path ([IO.Path]::GetTempPath()) ('sao-mousecat-helper-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$request=@{ViewId='target-view';NativeSession='ab37c02c-b28a-4d36-bb52-51f57b999105';Label='Exact target';
    Registry=(Join-Path $directory 'registry.json');FeedDirectory=(Join-Path $directory 'feed');
    EvidencePath=(Join-Path $directory 'receipt.json');OperatorUrl='http://127.0.0.1:4317';TimeoutSeconds=0}
$script:selected=0;$script:desktop=$true;$script:throwSelect=$false;$script:alreadySelected=$false
function Get-SelectionDesktop {if($script:desktop){return [pscustomobject]@{Id=77;MainWindowHandle=1}}}
function Select-DesktopView($App,$Request){$script:selected++;if($script:throwSelect){throw 'UI selection failed'};return @{visible=$true;selected=(-not $script:alreadySelected)}}
function Read-SelectionSnapshot($Request){return $script:snapshot}
function Reset {
    $script:selected=0;$script:desktop=$true;$script:throwSelect=$false;$script:alreadySelected=$false
    @(@{id=$request.ViewId;label=$request.Label;sessionId=$request.NativeSession;directory=$request.FeedDirectory}) |
        ConvertTo-Json | Set-Content -LiteralPath $request.Registry
    $script:snapshot=[pscustomobject]@{schema='mousecat.native-view-response/1';
        binding=[pscustomobject]@{id=$request.ViewId;label=$request.Label;bindingId=('a'*64)};
        connection='live';view=[pscustomobject]@{sessionId=$request.NativeSession;state='running';sequence=4;
            capturedAtUnixMs=42;lastCommandSequence=0;video=[pscustomobject]@{state='running';stats=[pscustomobject]@{encodedFrames=123}}}}
}
function Run {Invoke-OpenMousecat $request;return Get-Content -LiteralPath $request.EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json}
Reset
$result=Run
Check 'exact_live_selected_once' ($result.status -ceq 'PASS' -and $script:selected -eq 1 -and $result.bindingId -ceq ('a'*64))
Check 'receipt_has_exact_source_and_frames' ($result.viewId -ceq $request.ViewId -and $result.sessionId -ceq $request.NativeSession -and $result.sourceEncodedFrames -eq 123)
Reset
@(@{id='earlier-view';label='Earlier';sessionId='fe5c89f6-54d1-40e8-84c8-d850d84a0410';directory=($request.FeedDirectory+'-old')},
  @{id=$request.ViewId;label=$request.Label;sessionId=$request.NativeSession;directory=$request.FeedDirectory},
  @{id='later-view';label='Later';sessionId='59dc7ee1-dd4c-4b5b-8f2a-4cf18058e3ec';directory=($request.FeedDirectory+'-other')}) |
    ConvertTo-Json | Set-Content -LiteralPath $request.Registry -Encoding UTF8
$result=Run
Check 'multi_entry_registry_selects_exact_row' ($result.status -ceq 'PASS' -and $script:selected -eq 1)
Reset
$originalLabel=$request.Label;$request.Label='Caf'+[char]0xE9
$script:snapshot.binding.label=$request.Label
@(@{id=$request.ViewId;label=$request.Label;sessionId=$request.NativeSession;directory=$request.FeedDirectory}) |
    ConvertTo-Json | Set-Content -LiteralPath $request.Registry -Encoding UTF8
$result=Run
Check 'utf8_label_preserved' ($result.status -ceq 'PASS' -and $result.label -ceq $request.Label)
$request.Label=$originalLabel
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$fakeRoot=[pscustomobject]@{condition=$null}
$fakeRoot | Add-Member -MemberType ScriptMethod -Name FindFirst -Value {
    param($Scope,$Condition)
    $this.condition=$Condition
    return $null
}
$null=Find-SelectionToggle $fakeRoot
$conditions=@($fakeRoot.condition.GetConditions())
Check 'navigation_requires_toggle_capability' (@($conditions | Where-Object {
    $_.Property -eq [System.Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty -and $_.Value -eq $true}).Count -eq 1)
Reset;$script:alreadySelected=$true;$result=Run
Check 'already_selected_receipt_has_no_invocation' ($result.status -ceq 'PASS' -and $result.selectionPerformed -eq $false)
Reset;$script:desktop=$false;$result=Run
Check 'absent_desktop_unavailable' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
Reset;$script:snapshot.view.sessionId='d47dca6e-81a1-43d9-9da5-dc8113dc76b2';$result=Run
Check 'reject_wrong_snapshot' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
Reset;$script:snapshot.binding.id='different-view';$result=Run
Check 'reject_wrong_view' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
foreach($state in @('stale','disconnected','ended')){
    Reset;$script:snapshot.connection=$state;$result=Run
    Check ('reject_'+$state) ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
}
Reset;$script:snapshot.view.state='ended';$result=Run
Check 'ended_state_cannot_claim_live' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
Reset
@(@{id=$request.ViewId;label=$request.Label;sessionId=$request.NativeSession;directory=($request.FeedDirectory+'-wrong')}) |
    ConvertTo-Json | Set-Content -LiteralPath $request.Registry
$result=Run
Check 'reject_wrong_feed_directory' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
Reset
@(@{id=$request.ViewId;label=$request.Label;sessionId=$request.NativeSession;directory=$request.FeedDirectory},
  @{id='other-view';label=$request.Label;sessionId=$request.NativeSession;directory=$request.FeedDirectory}) |
    ConvertTo-Json | Set-Content -LiteralPath $request.Registry
$result=Run
Check 'duplicate_label_refused' ($result.status -ceq 'unavailable' -and $script:selected -eq 0)
Reset;$script:throwSelect=$true;$result=Run
Check 'ui_failure_no_retry' ($result.status -ceq 'error' -and $script:selected -eq 1)
Reset;$request.OperatorUrl='https://example.com';$result=Run
Check 'remote_endpoint_refused' ($result.status -ceq 'error' -and $script:selected -eq 0)
# These are mocked workflow tests; root separately checks real installed UIA behavior.
Write-Output "PASS open Mousecat helper $checks"

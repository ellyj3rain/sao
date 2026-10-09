param([Parameter(Mandatory=$true)][string]$Helper,[Parameter(Mandatory=$true)][string]$OriginalReceipt,
    [Parameter(Mandatory=$true)][string]$Registry,[Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
$readOnlyArguments=@{OriginalReceipt=$OriginalReceipt;Registry=$Registry;Output=$Output}
. $Helper
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$original=Get-Content -LiteralPath $readOnlyArguments.OriginalReceipt -Raw -Encoding UTF8 | ConvertFrom-Json
$request=@{Label=$original.label;ViewId=$original.viewId;NativeSession=$original.sessionId;
    FeedDirectory=$original.feedDirectory;Registry=$readOnlyArguments.Registry;OperatorUrl='http://127.0.0.1:4317'}
$app=Get-SelectionDesktop
if($null -eq $app){throw 'Exactly one original desktop is required'}
$root=[System.Windows.Automation.AutomationElement]::FromHandle($app.MainWindowHandle)
$before=Read-SelectionUiState $root $request
if(-not $before.selectorVisible -or -not $before.headingVisible -or $before.value -cne $request.Label){throw 'Requested source is not currently selected'}
$processes=@(Get-CimInstance Win32_Process)
$owners=[Collections.Generic.HashSet[int]]::new();[void]$owners.Add($app.Id)
do{$added=$false;foreach($process in $processes){if($owners.Contains([int]$process.ParentProcessId)){
    if($owners.Add([int]$process.ProcessId)){$added=$true}}}}while($added)
if(-not $owners.Contains($before.selector.Current.ProcessId)){throw 'Selector is outside original desktop family'}
# The production readiness loop is exercised with genuine current UIA reads;
# every mutation adapter throws before any focus, popup or invocation change.
function Open-SelectionPopup($Selector){throw 'Read-only evidence refuses popup/focus changes'}
function Close-SelectionPopup($Expand){if($null -ne $Expand){throw 'Read-only evidence refuses popup changes'}}
function Invoke-SelectionOption($Option){throw 'Read-only evidence refuses selection changes'}
$selected=Complete-DesktopSelection $root $request $owners
if(-not $selected.visible -or $selected.selected){throw 'Read-only readiness mutated or failed'}
$null=Read-SelectionBinding $request
$snapshot=Read-SelectionSnapshot $request
$after=Read-SelectionUiState $root $request
$current=Get-SelectionDesktop
if($null -eq $current -or $current.Id -ne $app.Id -or $before.value -cne $after.value -or
    -not $after.headingVisible -or -not $after.selectorVisible){throw 'Desktop source changed during read-only evidence'}
$receipt=@{schema='sao.mousecat-readiness-native/1';status='PASS';recordedAt=[DateTime]::UtcNow.ToString('o');
    desktopPid=$app.Id;selectorProcessId=$before.selector.Current.ProcessId;selectorType=$before.selector.Current.ControlType.ProgrammaticName;
    label=$request.Label;sessionId=$request.NativeSession;viewId=$request.ViewId;exactSelectedValue=$after.value;
    exactHeadingVisible=$after.headingVisible;selectionPerformed=$selected.selected;mutationsAllowed=$false;
    bindingId=$snapshot.binding.bindingId;connection=$snapshot.connection;state=$snapshot.view.state;
    liveAcceptance=(Test-SelectionSnapshot $request $snapshot);
    limits='Current UIA readiness only; no rendered-pixel or historical race attribution; existing source freshness/ended guard retained'}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($readOnlyArguments.Output),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Output 'PASS read-only native Mousecat readiness; zero selection/focus/popup changes'

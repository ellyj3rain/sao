param(
    [string]$ViewId, [string]$NativeSession, [string]$Label,
    [string]$Registry, [string]$FeedDirectory, [string]$EvidencePath,
    [string]$OperatorUrl='http://127.0.0.1:4317',
    [ValidateRange(0,1800)][int]$TimeoutSeconds=360
)
$ErrorActionPreference='Stop'

function Save-SelectionReceipt($Request, $Details) {
    $value=@{schema='sao.open-mousecat/1'; viewId=$Request.ViewId; sessionId=$Request.NativeSession;
        label=$Request.Label; feedDirectory=$Request.FeedDirectory; recordedAt=[DateTime]::UtcNow.ToString('o')}
    foreach($key in $Details.Keys){$value[$key]=$Details[$key]}
    $path=[IO.Path]::GetFullPath($Request.EvidencePath)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    $temporary=$path+'.tmp'
    [IO.File]::WriteAllText($temporary,($value | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $path -Force
}

function Get-SelectionDesktop {
    $apps=@(Get-Process Mousecat -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0})
    if($apps.Count -ne 1){return $null}
    return $apps[0]
}

function Read-SelectionBinding($Request) {
    # Windows PowerShell 5.1 emits a JSON array as one pipeline object. Decode
    # before array enumeration so filtering operates on individual bindings.
    $decoded=Get-Content -LiteralPath $Request.Registry -Raw -Encoding UTF8 | ConvertFrom-Json
    $rows=@($decoded)
    $matches=@($rows | Where-Object {$_.id -ceq $Request.ViewId})
    if($matches.Count -ne 1){throw 'Target view is not uniquely registered'}
    $row=$matches[0]
    if($row.sessionId -cne $Request.NativeSession -or $row.label -cne $Request.Label -or
        [IO.Path]::GetFullPath($row.directory) -ine [IO.Path]::GetFullPath($Request.FeedDirectory)) {
        throw 'Target source binding differs'
    }
    if(@($rows | Where-Object {$_.label -ceq $Request.Label}).Count -ne 1){throw 'Target label is ambiguous'}
    return $row
}

function Read-SelectionSnapshot($Request) {
    $view=[Uri]::EscapeDataString($Request.ViewId)
    return Invoke-RestMethod -Uri ($Request.OperatorUrl.TrimEnd('/')+"/api/native-views/$view/snapshot") -TimeoutSec 5
}

function Test-SelectionSnapshot($Request, $Snapshot) {
    return $null -ne $Snapshot -and $Snapshot.schema -ceq 'mousecat.native-view-response/1' -and
        $Snapshot.binding.id -ceq $Request.ViewId -and $Snapshot.binding.label -ceq $Request.Label -and
        $Snapshot.binding.bindingId -match '^[a-f0-9]{64}$' -and
        $Snapshot.view.sessionId -ceq $Request.NativeSession -and $Snapshot.connection -ceq 'live' -and
        $Snapshot.view.state -cne 'ended'
}

function Find-SelectionElement($Root, [string]$Name) {
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::NameProperty,$Name))
}

function Find-SelectionHeading($Root, [string]$Label) {
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.AndCondition]::new(
            [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::NameProperty,$Label),
            [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Text)))
}

function Find-SelectionToggle($Root) {
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.AndCondition]::new(
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::NameProperty,'Simulation'),
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty,$true)))
}

function Read-SelectionUiState($Root, $Request) {
    $selector=Find-SelectionElement $Root 'Simulation session'
    $value=$null;$label=$null
    if($null -ne $selector -and $selector.TryGetCurrentPattern(
        [System.Windows.Automation.ValuePattern]::Pattern,[ref]$value)){$label=$value.Current.Value}
    $heading=Find-SelectionHeading $Root $Request.Label
    $currentHeading=$null
    if($label){$currentHeading=Find-SelectionHeading $Root $label}
    return @{selector=$selector;value=$label;
        selectorVisible=($null -ne $selector -and -not $selector.Current.IsOffscreen);
        headingVisible=($null -ne $heading -and -not $heading.Current.IsOffscreen);
        currentHeadingVisible=($null -ne $currentHeading -and -not $currentHeading.Current.IsOffscreen)}
}

function Test-SelectionOption($Option, $Request, $Owners, [switch]$IncludeOffscreen) {
    return $Option.Current.Name -ceq $Request.Label -and $Owners.Contains([int]$Option.Current.ProcessId) -and
        ($IncludeOffscreen -or -not $Option.Current.IsOffscreen) -and $Option.Current.IsEnabled -and
        ($Option.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::IsInvokePatternAvailableProperty) -eq $true -or
            ($IncludeOffscreen -and $Option.GetCurrentPropertyValue(
                [System.Windows.Automation.AutomationElement]::IsSelectionItemPatternAvailableProperty) -eq $true))
}

function Read-SelectionOptions($Request, $Owners, [switch]$IncludeOffscreen) {
    return @([System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::ListItem)) |
        Where-Object {Test-SelectionOption $_ $Request $Owners -IncludeOffscreen:$IncludeOffscreen})
}

function Open-SelectionPopup($Selector) {
    $Selector.SetFocus()
    $expand=[System.Windows.Automation.ExpandCollapsePattern]$Selector.GetCurrentPattern(
        [System.Windows.Automation.ExpandCollapsePattern]::Pattern)
    if($expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed){$expand.Expand()}
    return $expand
}

function Close-SelectionPopup($Expand) {
    if($null -ne $Expand -and $Expand.Current.ExpandCollapseState -eq
        [System.Windows.Automation.ExpandCollapseState]::Expanded){$Expand.Collapse()}
}

function Test-SelectionTypedOption($Option, $Request, $Owners) {
    return (Test-SelectionOption $Option $Request $Owners -IncludeOffscreen) -and
        $Option.Current.ControlType -eq [System.Windows.Automation.ControlType]::ListItem -and
        $Option.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::IsSelectionItemPatternAvailableProperty) -eq $true
}

function Confirm-SelectionSource($Request) {
    $desktop=Get-SelectionDesktop
    if($null -eq $desktop -or $desktop.Id -ne $Request.SelectionDesktopPid -or
        [long]$desktop.MainWindowHandle -ne $Request.SelectionDesktopHwnd){throw 'Original Mousecat desktop changed before typed selection'}
    $null=Read-SelectionBinding $Request
    $fresh=Read-SelectionSnapshot $Request
    if(-not (Test-SelectionSnapshot $Request $fresh) -or
        $fresh.binding.bindingId -cne $Request.SelectionBindingId){throw 'Exact live source changed before typed selection'}
}

function Apply-SelectionItem($Option) {
    ([System.Windows.Automation.SelectionItemPattern]$Option.GetCurrentPattern(
        [System.Windows.Automation.SelectionItemPattern]::Pattern)).Select()
}

function Scroll-SelectionOption($Option, $Request, $Owners) {
    if(-not (Test-SelectionOption $Option $Request $Owners -IncludeOffscreen) -or
        -not $Option.Current.IsOffscreen -or
        $Option.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::IsScrollItemPatternAvailableProperty) -ne $true){
        return $false
    }
    ([System.Windows.Automation.ScrollItemPattern]$Option.GetCurrentPattern(
        [System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView()
    return $true
}

function Invoke-SelectionOption($Option) {
    ([System.Windows.Automation.InvokePattern]$Option.GetCurrentPattern(
        [System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
}

function Complete-DesktopSelection($Root, $Request, $Owners) {
    $initial=Read-SelectionUiState $Root $Request
    if(-not $initial.selectorVisible){throw 'Simulation selector unavailable'}
    $initialValue=$initial.value;$targetSeen=($initial.value -ceq $Request.Label)
    $expand=$null;$invoked=$false;$optionCount=0;$scrollAttempted=$false;$scrolled=$false;$selectionMethod=$null
    try {
        for($attempt=0;$attempt -lt 20;$attempt++){
            $state=Read-SelectionUiState $Root $Request
            if(-not $state.selectorVisible){throw 'Simulation navigation changed; selection was not repeated'}
            if(-not $Owners.Contains([int]$state.selector.Current.ProcessId)){throw 'Simulation selector process changed'}
            if($state.value -ceq $Request.Label){
                $targetSeen=$true
                if($state.headingVisible){return @{visible=$true;selected=$invoked;readinessPolls=($attempt+1);popupMatches=$optionCount;scrollAttempted=$scrollAttempted;scrolled=$scrolled;selectionMethod=$selectionMethod}}
            } elseif(($targetSeen -and $state.value) -or
                ($state.value -and $initialValue -and $state.value -cne $initialValue)){
                throw 'Simulation choice changed during readiness; selection was not repeated'
            }
            # Selection and heading update asynchronously. A source already
            # chosen by Mousecat needs readiness verification, not invocation.
            if(-not $invoked -and -not $targetSeen){
                if($null -eq $expand){$expand=Open-SelectionPopup $state.selector}
                $candidates=@(Read-SelectionOptions $Request $Owners -IncludeOffscreen)
                if($candidates.Count -gt 1){throw 'Requested simulation is ambiguously available in this desktop'}
                $options=@($candidates | Where-Object {Test-SelectionOption $_ $Request $Owners});$optionCount=$options.Count
                if($options.Count -eq 0 -and $candidates.Count -eq 1 -and -not $scrollAttempted){
                    $beforeScroll=Read-SelectionUiState $Root $Request
                    if(-not $beforeScroll.selectorVisible -or -not $Owners.Contains([int]$beforeScroll.selector.Current.ProcessId) -or
                        ($beforeScroll.value -and $beforeScroll.value -cne $Request.Label -and -not $beforeScroll.currentHeadingVisible)){
                        throw 'Simulation navigation changed; selection was not repeated'
                    }
                    if($beforeScroll.value -ceq $Request.Label){$targetSeen=$true}
                    elseif($beforeScroll.value -and $initialValue -and $beforeScroll.value -cne $initialValue){
                        throw 'Simulation choice changed during readiness; selection was not repeated'
                    } else {
                        if(Test-SelectionTypedOption $candidates[0] $Request $Owners){
                            Confirm-SelectionSource $Request
                            $typedReady=Read-SelectionUiState $Root $Request
                            if(-not $typedReady.selectorVisible -or -not $Owners.Contains([int]$typedReady.selector.Current.ProcessId) -or
                                ($typedReady.value -and $typedReady.value -cne $Request.Label -and -not $typedReady.currentHeadingVisible)){
                                throw 'Simulation navigation changed; selection was not repeated'
                            }
                            if($typedReady.value -ceq $Request.Label){$targetSeen=$true}
                            elseif($typedReady.value -and $initialValue -and $typedReady.value -cne $initialValue){
                                throw 'Simulation choice changed during readiness; selection was not repeated'
                            } else {
                                $typedCandidates=@(Read-SelectionOptions $Request $Owners -IncludeOffscreen)
                                if($typedCandidates.Count -gt 1){throw 'Requested simulation is ambiguously available in this desktop'}
                                if($typedCandidates.Count -ne 1 -or -not (Test-SelectionTypedOption $typedCandidates[0] $Request $Owners)){throw 'Typed selection option changed'}
                                Apply-SelectionItem $typedCandidates[0]
                                $invoked=$true;$selectionMethod='SelectionItem'
                                Close-SelectionPopup $expand;$expand=$null
                            }
                        } else {
                            $scrollAttempted=$true
                            $scrolled=Scroll-SelectionOption $candidates[0] $Request $Owners
                        }
                    }
                    # One source-specific scroll only; requery its current UI row
                    # and navigation on the next bounded readiness iteration.
                }
                if($options.Count -eq 1){
                    # Requery after the popup scan: auto-follow may have selected
                    # the exact source while its option subtree was changing.
                    $ready=Read-SelectionUiState $Root $Request
                    if(-not $ready.selectorVisible -or -not $Owners.Contains([int]$ready.selector.Current.ProcessId)){
                        throw 'Simulation navigation changed; selection was not repeated'
                    }
                    if($ready.value -ceq $Request.Label){$targetSeen=$true}
                    elseif($ready.value -and $initialValue -and $ready.value -cne $initialValue){
                        throw 'Simulation choice changed during readiness; selection was not repeated'
                    } else {
                        Confirm-SelectionSource $Request
                        $invokeReady=Read-SelectionUiState $Root $Request
                        if(-not $invokeReady.selectorVisible -or -not $Owners.Contains([int]$invokeReady.selector.Current.ProcessId) -or
                            ($invokeReady.value -and $invokeReady.value -cne $Request.Label -and -not $invokeReady.currentHeadingVisible)){
                            throw 'Simulation navigation changed; selection was not repeated'
                        }
                        if($invokeReady.value -ceq $Request.Label){$targetSeen=$true}
                        elseif($invokeReady.value -and $initialValue -and $invokeReady.value -cne $initialValue){
                            throw 'Simulation choice changed during readiness; selection was not repeated'
                        } else {
                            $invokeCandidates=@(Read-SelectionOptions $Request $Owners -IncludeOffscreen)
                            if($invokeCandidates.Count -gt 1){throw 'Requested simulation is ambiguously available in this desktop'}
                            if($invokeCandidates.Count -ne 1 -or -not (Test-SelectionOption $invokeCandidates[0] $Request $Owners)){
                                throw 'Visible selection option changed'
                            }
                            Invoke-SelectionOption $invokeCandidates[0]
                            $invoked=$true;$selectionMethod='Invoke'
                            Close-SelectionPopup $expand;$expand=$null
                        }
                    }
                }
            }
            Start-Sleep -Milliseconds 250
        }
        if($invoked -or $targetSeen){throw 'Selected observation heading was not visible; selection was not repeated'}
        throw ('Requested simulation is not uniquely available in this desktop; visible invokable matches='+$optionCount)
    } finally {Close-SelectionPopup $expand}
}

function Select-DesktopView($App, $Request) {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $root=[System.Windows.Automation.AutomationElement]::FromHandle($App.MainWindowHandle)
    $window=[System.Windows.Automation.WindowPattern]$root.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
    if($window.Current.WindowVisualState -eq [System.Windows.Automation.WindowVisualState]::Minimized){
        $window.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Normal)
    }
    $selector=Find-SelectionElement $root 'Simulation session'
    if($null -eq $selector -or $selector.Current.IsOffscreen){
        $simulation=Find-SelectionToggle $root
        if($null -eq $simulation -or $simulation.Current.IsOffscreen){throw 'Simulation navigation unavailable'}
        $toggle=[System.Windows.Automation.TogglePattern]$simulation.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        if($toggle.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On){$toggle.Toggle()}
        for($attempt=0;$attempt -lt 40;$attempt++){
            $selector=Find-SelectionElement $root 'Simulation session'
            if($null -ne $selector -and -not $selector.Current.IsOffscreen){break}
            Start-Sleep -Milliseconds 250
        }
    }
    if($null -eq $selector -or $selector.Current.IsOffscreen){throw 'Simulation selector unavailable'}
    # The native select popup is a separate UIA subtree. Restrict it to this app's
    # process family, including WebView children, before matching the unique label.
    $processes=@(Get-CimInstance Win32_Process)
    $owners=[Collections.Generic.HashSet[int]]::new();[void]$owners.Add($App.Id)
    [void]$owners.Add($selector.Current.ProcessId)
    do {
        $added=$false
        foreach($process in $processes){
            if($owners.Contains([int]$process.ParentProcessId)){
                if($owners.Add([int]$process.ProcessId)){$added=$true}
            }
        }
    } while($added)
    return Complete-DesktopSelection $root $Request $owners
}

function Invoke-OpenMousecat($Request) {
    try {
        $endpoint=[Uri]$Request.OperatorUrl
        if(-not $endpoint.IsLoopback -or $endpoint.Scheme -notin @('http','https')){throw 'Operator endpoint must be local HTTP(S)'}
        if($Request.ViewId -cnotmatch '^[a-z0-9][a-z0-9-]{0,79}$' -or
            ([Guid]$Request.NativeSession).ToString() -cne $Request.NativeSession){throw 'Target identity is invalid'}
        $app=Get-SelectionDesktop
        if($null -eq $app){
            Save-SelectionReceipt $Request @{status='unavailable';reason='Exactly one open Mousecat window is required'}
            return
        }
        Save-SelectionReceipt $Request @{status='waiting';desktopPid=$app.Id;reason='Waiting for the exact live source'}
        $deadline=[DateTime]::UtcNow.AddSeconds($Request.TimeoutSeconds)
        $snapshot=$null;$reason='Target source not yet live'
        do {
            try {
                $null=Read-SelectionBinding $Request
                $candidate=Read-SelectionSnapshot $Request
                if(Test-SelectionSnapshot $Request $candidate){$snapshot=$candidate;break}
                $reason='Target source is not live or its identity differs'
            } catch {$reason=$_.Exception.Message}
            if([DateTime]::UtcNow -ge $deadline){break}
            Start-Sleep -Milliseconds 500
        } while($true)
        if($null -eq $snapshot){Save-SelectionReceipt $Request @{status='unavailable';reason=$reason;desktopPid=$app.Id};return}
        $currentApp=Get-SelectionDesktop
        if($null -eq $currentApp -or $currentApp.Id -ne $app.Id){throw 'Original Mousecat desktop is no longer available'}
        $Request.SelectionBindingId=$snapshot.binding.bindingId
        $Request.SelectionDesktopPid=$app.Id
        $Request.SelectionDesktopHwnd=[long]$app.MainWindowHandle
        $selection=Select-DesktopView $currentApp $Request
        $verifiedApp=Get-SelectionDesktop
        if($null -eq $verifiedApp -or $verifiedApp.Id -ne $app.Id){throw 'Original Mousecat desktop changed during verification'}
        $null=Read-SelectionBinding $Request
        $after=Read-SelectionSnapshot $Request
        if($selection.visible -ne $true -or -not (Test-SelectionSnapshot $Request $after) -or
            $after.binding.bindingId -cne $snapshot.binding.bindingId){throw 'Selected source changed during verification'}
        Save-SelectionReceipt $Request @{status='PASS';desktopPid=$app.Id;visible=$true;selectionPerformed=$selection.selected;
            selectionReadinessPolls=$selection.readinessPolls;selectionPopupMatches=$selection.popupMatches;selectionMethod=$selection.selectionMethod;
            selectionScrollAttempted=$selection.scrollAttempted;selectionScrolled=$selection.scrolled;
            bindingId=$after.binding.bindingId;connection=$after.connection;
            sourceSequence=$after.view.sequence;sourceCapturedAtUnixMs=$after.view.capturedAtUnixMs;
            sourceVideoState=$after.view.video.state;sourceEncodedFrames=$after.view.video.stats.encodedFrames;
            sourceLastCommandSequence=$after.view.lastCommandSequence;
            method='One installed UI session selection; exact live source verified by read-only API';
            limits='Visible selected heading and live source frames; rendered video pixels are not measured by this helper'}
    } catch {
        Save-SelectionReceipt $Request @{status='error';reason=$_.Exception.Message}
    }
}

# Dot-sourcing defines the same production functions for isolated mock tests.
if($MyInvocation.InvocationName -ne '.'){
    Invoke-OpenMousecat @{ViewId=$ViewId;NativeSession=$NativeSession;Label=$Label;Registry=$Registry;
        FeedDirectory=$FeedDirectory;EvidencePath=$EvidencePath;OperatorUrl=$OperatorUrl;TimeoutSeconds=$TimeoutSeconds}
}

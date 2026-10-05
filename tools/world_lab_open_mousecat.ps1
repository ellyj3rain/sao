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
    $value=$null
    $heading=Find-SelectionHeading $root $Request.Label
    if($selector.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$value) -and
        $value.Current.Value -ceq $Request.Label -and $null -ne $heading -and -not $heading.Current.IsOffscreen){
        return @{visible=$true;selected=$false}
    }
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
    $selector.SetFocus()
    $expand=[System.Windows.Automation.ExpandCollapsePattern]$selector.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
    if($expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed){$expand.Expand()}
    try {
        $options=@()
        for($attempt=0;$attempt -lt 20;$attempt++){
            $options=@([System.Windows.Automation.AutomationElement]::RootElement.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.PropertyCondition]::new(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::ListItem)) |
                Where-Object {$_.Current.Name -ceq $Request.Label -and $owners.Contains($_.Current.ProcessId)})
            if($options.Count -eq 1){break}
            Start-Sleep -Milliseconds 250
        }
        if($options.Count -ne 1){throw 'Requested simulation is not uniquely available in this desktop'}
        # A single invocation. Verification below never reselects after operator navigation.
        ([System.Windows.Automation.InvokePattern]$options[0].GetCurrentPattern(
            [System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
    } finally {
        if($expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Expanded){$expand.Collapse()}
    }
    for($attempt=0;$attempt -lt 20;$attempt++){
        $heading=Find-SelectionHeading $root $Request.Label
        $value=$null
        if($null -ne $heading -and -not $heading.Current.IsOffscreen -and
            $selector.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$value) -and
            $value.Current.Value -ceq $Request.Label){return @{visible=$true;selected=$true}}
        Start-Sleep -Milliseconds 250
    }
    throw 'Selected observation heading was not visible; selection was not repeated'
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
        $selection=Select-DesktopView $currentApp $Request
        $null=Read-SelectionBinding $Request
        $after=Read-SelectionSnapshot $Request
        if($selection.visible -ne $true -or -not (Test-SelectionSnapshot $Request $after) -or
            $after.binding.bindingId -cne $snapshot.binding.bindingId){throw 'Selected source changed during verification'}
        Save-SelectionReceipt $Request @{status='PASS';desktopPid=$app.Id;visible=$true;selectionPerformed=$selection.selected;
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

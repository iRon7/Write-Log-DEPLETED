<#PSScriptInfo
.VERSION 0.0.1
.GUID 19631007-3888-4a3a-8950-865fb1cd7717
.DESCRIPTION logs GovRoam status
.COMPANYNAME JIO
.COPYRIGHT Ronald Bode (iRon)
.TAGS GovRoam WiFi log
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA
#>

<#
.SYNOPSIS
    Reconnects the GovRoam connection and logs the status

.DESCRIPTION
    A temporary solution until Cisco Aironet sensors can be deployed is to use a Windows PC with a network connection and a WiFi card.
    A Powershell script must be run periodically on the PC, which performs the following steps:
    * Disable network card
    * Enable WiFi card
    * Log in to govroam with a JIO account
    * And immediately log off again
    * Log in to govroam with a DUO account (or, depending on the location, an account of another IDV-G)
    * And immediately log off again
    * Enable network card
    * Activate the MicroFocus OBM agent that passes on the results of the 2 login attempts to the central OBM platform that determines availability based on availability. triggers monitored.

    Because govroam accounts generally have a limited lifespan, the passwords used in scripts and possibly also accounts must be periodically renewed.
#>

[cmdletBinding()]
param(
    [String]$NetAdpaterName,
    [Int]$AdaperTimeout = 10, # Seconds
    [Int]$UserTimeout = 30    # Seconds
)

Install-Module -Name wifiprofilemanagement -Confirm:$False

Function SSO_WriteLog {
<#
.SYNOPSIS
    Dispatches log information

.DESCRIPTION
    Write log information to the console so that it can be picked up by Ivanti Automation
    The information written to the (host) display uses the following format:

    yyyy-MM-dd HH:mm:ss [Labels[]]<ScriptName>: <Message>

    Where:
    * yyyy-MM-dd HH:mm:ss is the sortable date/time where the log entry occurred
    * [Labels[]] represents one or more of the following colored labels:
        [ERROR]
        [FAILURE]
        [WARNING]
        [INFO]
        [DEBUG]
        [VERBOSE]
        [WHATIF]
        Note that each label could be combined with another label except for the [ERROR] and [FAILURE]
        which are exclusive and the [INFO] label which only set if none of the other labels applies
        (See also the -Warning and -Failure parameter)
    * <ScriptName> represents the script that called this SSO_WriteLog cmdlet
    * <Message> is a string representation of the -Object parameter
        Note that if the -Object contains an [ErrorRecord] type, the error label is set and the error
        record is output in a single line:

        at <LineNumber> char:<Offset> <Error Statement> <Error Message>

        Where:
        * <LineNumber> represents the line where the error occurred
        * <Offset> represents the offset in the line where the error occurred
        * <Error Statement> represents the statement that caused the error
        * <error message> represents the description of the error

.PARAMETER Object
    Writes the object as a string to the host from a script or command.
    If the object is of an [ErrorRecord] type, the [ERROR] label will be added and the error
    name and position are written to the host from a script or command unless the $ErrorPreference
    is set to SilentlyContinue.

.PARAMETER Warning
    Writes warning messages to the host from a script or command unless the $WarningPreference
    is set to SilentlyContinue.

.PARAMETER Failure
    Writes failure messages to the host from a script or command unless the $ErrorPreference
    is set to SilentlyContinue.

    Note that the common parameters -Debug and -Verbose have a simular behavor as the -Warning
    and -Failure Parameter and will not be shown if the corresponding $<name>preference variable
    is set to 'SilentlyContinue'.

.PARAMETER Path
    The path to a log file. If set, the complete entry will also output to a log file.

.PARAMETER Tee
    Logs (displays) the output and also sends it down the pipeline.

.PARAMETER WriteActivity
    By default, the current activity (message) is only exposed (using the Write-Progress cmdlet)
    when it is invoked from Ivanti Automation. This switch (-WriteActivity or -WriteActivity:$False)
    will overrule the default behavior. The default behavior might also be overruled from Ivanti
    Automation by sening the Ivanti module parmater "par_m_disable_activity" to "false".
    (The script parameter, -WriteActivity, takes president).

.PARAMETER WriteEvent
    When set, this cmdlet will also write the message to the Windows Application EventLog.
    Where:
    * If the [EventSource] parameter is ommited, the Source will be "Automation"
    * The Category represents the concerned labels:
        Info    = 0
        Verbose = 1
        Debug   = 2
        WhatIf  = 4
        Warning = 8
        Failure = 16
        Error   = 32
    * The Message is a string representation of the object
    * If [EventId] parameter is ommited, the EventID will be a 32bit hashcode based on the message
    * EventType is "Error" in case of an error or when the -Failure parameter is set,
        otherwise "Warning" if the -Warning parameter is set and "Information" by default.

    Note 1: logging Windows Events, requires elevated rights if the event source does not yet exist.
    Note 2: This parameter is not required if the [EventSource] - or [EventId] parameter is supplied.

.PARAMETER EventSource
    When defined, this cmdlet will also write the message to the given EventSource in the
    Windows Application EventLog. For details see the [WriteEvent] parameter.

.PARAMETER EventId
    When defined, this cmdlet will also write the message Windows Application EventLog using the
    specified EventId. For details see the [WriteEvent] parameter.

.PARAMETER Type
    This parameter will show if the log information is from type INFO, WARNING or Error.
    * Warning: this parameter is depleted, use the corresponding switch as e.g. `-Warning`.

.PARAMETER Message
    This parameter contains the message that wil be shown.
    * Warning: this parameter is depleted, use the `-Object` parameter instead.

.PARAMETER Logpath
    This parameter contains the log file path.
    * Warning: this parameter is depleted, use the `-Path` parameter instead.

.EXAMPLE
    # Log a message

    Displays the following entry and updates the progress activity in Ivanti Automation:

        SSO_WriteLog 'Deploying VM'
        2022-08-10 11:56:12 [INFO] MyScript: Deploying VM

.EXAMPLE
    # Log and save a warning

    Displays `File not found` with a `[WARNING]` as shown below, updates the progress activity
    in Ivanti Automation. Besides, it writes the warning to the file: c:\temp\log.txt and create
    and add an entry to the EventLog.

        SSO_WriteLog -Warning 'File not found' -Path c:\temp\log.txt -WriteEvent
        2022-08-10 12:03:51 [WARNING] MyScript: File not found

.EXAMPLE
    # Log and capure a message

    Displays `my message` as shown below and capture the message in the `$Log` variable.

        $Log = SSO_WriteLog 'My message' -Tee
        2022-08-10 12:03:51 [INFO] MyScript: File not found

.LINK
    https://confluence.dji.minvenj.nl/display/AUT/SSO_WriteLog
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding(DefaultParameterSetName = 'Warning')]
    param(
        [Parameter(ParameterSetName = 'Warning', Position = 0, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'Failure', Position = 0, ValueFromPipeline = $true)]
        $Object,

        [Parameter(ParameterSetName = 'Warning')]
        [switch] $Warning,

        [Parameter(ParameterSetName = 'Failure')]
        [switch] $Failure,

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [string] $Path,

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [switch] $WriteActivity,

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [switch] $WriteEvent,

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [string] $EventSource = 'Automation',

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [int] $EventId = -1,

        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Failure')]
        [switch] $Tee,

        [Parameter(ParameterSetName = 'Legacy', Position = 0, Mandatory = $true)]
        [Validateset("INFO", "WARNING", "ERROR", "DEBUG")]
        [Alias('LogType')][string] $Type,

        [Parameter(ParameterSetName = 'Legacy', Position = 1, Mandatory = $true)]
        [string]$Message,

        [Parameter(ParameterSetName = 'Legacy')]
        [Alias('LogPath')][string] $FilePath
    )

    begin {
        if (!$Global:SSO_WriteLog) { $Global:SSO_WriteLog = @{} }

        $PSCallStack = Get-PSCallStack
        $Commands = @($PSCallStack.Command)
        $Me = $Commands[0]
        $Caller = if ($Commands -gt 1) { $Commands[1..($Commands.Length)].where({ $_ -ne $Me }, 'First') }
        if (!$Caller) { $Caller = '' } # Prevent that the array index evaluates to null.
        $MeAgain = $Commands -gt 2 -and $Commands[2] -eq $Me

        if (!$Global:SSO_WriteLog.Contains($Caller)) {
            # if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
            #     SSO_WriteLog -Warning "Use the new implementation: $($MyInvocation.MyCommand) [-Warning|-Failure] 'message'"
            # }
            $Global:SSO_WriteLog[$Caller] = @{}
        }

        if ($PSCmdlet.ParameterSetName -eq 'Legacy') {

            switch ($Type) {
                'INFO'    { $TypeColor = 'Green'; $ThrowError = $false }
                'WARNING' { $TypeColor = 'Yellow'; $ThrowError = $false }
                'DEBUG'   { $TypeColor = 'Cyan'; $ThrowError = $false }
                'ERROR'   { $TypeColor = 'Red'; $ThrowError = $true }
            }

            $ChunksEntry = $(Get-Date -Format '[dd-MM-yyyy][HH:mm:ss]') + $("[" + $Type.padright(7) + "] ")

            # Exit script if "$Type -eq "DEBUG" -and $VerbosePreference -eq "SilentlyContinue"
            if ($Type -eq "DEBUG" -and $VerbosePreference -eq "SilentlyContinue") { return }

            Write-host $ChunksEntry -ForegroundColor $TypeColor -NoNewline
            if ($ThrowError) { Write-Error $Message } else { Write-Host $Message }

            if ($FilePath) {
                Try { $($ChunksEntry + $Message) | Out-File -FilePath $FilePath -Append }
                Catch { SSO_WriteLog -Warning "Can not write to logfile $FilePath" }
            }
        }
        else {

            [Flags()] enum EventFlag
            {
                Info    = 0
                Verbose = 1
                Debug   = 2
                WhatIf  = 4
                Warning = 8
                Failure = 16
                Error   = 32
            }

            $IsVerbose   = $PSBoundParameters.Verbose.IsPresent
            $VerboseMode = $IsVerbose -and $PSCmdlet.SessionState.PSVariable.Get('VerbosePreference').Value -ne 'SilentlyContinue'

            $IsDebug     = $PSBoundParameters.Debug.IsPresent
            $DebugMode   = $IsDebug -and $PSCmdlet.SessionState.PSVariable.Get('DebugPreference').Value -ne 'SilentlyContinue'

            $WhatIfMode  = $PSCmdlet.SessionState.PSVariable.Get('WhatIfPreference').Value

            $WriteEvent = $WriteEvent -or $PSBoundParameters.ContainsKey('EventSource') -or $PSBoundParameters.ContainsKey('EventID')
            if ($PSBoundParameters.ContainsKey('Path')) { $Global:SSO_WriteLog[$Caller].Path = $Path } # Reset with: -Path ''
        }

        function WriteLog {
            if ($Failure -and !$Object) {
                $Object = if ($Error.Count) { $Error[0] } else { '<No error found>' }
            }

            $IsError   = $Object -is [System.Management.Automation.ErrorRecord]

            $Category = [EventFlag]::new(); $EventType = 'Information'
            if ($ErrorPreference   -ne 'SilentlyContinue' -and $IsError) { $Category += [EventFlag]::Error }
            if ($ErrorPreference   -ne 'SilentlyContinue' -and $Failure) { $Category += [EventFlag]::Failure }
            if ($WarningPreference -ne 'SilentlyContinue' -and $Warning) { $Category += [EventFlag]::Warning }
            if ($IsDebug)    { $Category += [EventFlag]::Debug }
            if ($IsVerbose)  { $Category += [EventFlag]::Verbose }
            if ($WhatIfMode) { $Category += [EventFlag]::WhatIf }
            $IsInfo = !$Category

            $ColorText = [System.Collections.Generic.List[HashTable]]::new()
            $ColorText.Add( @{ Object = Get-Date -Format 'yyyy-MM-dd HH:mm:ss ' } )

            if ($IsError)     { $ColorText.Add(@{ BackgroundColor = 'Red';     ForegroundColor = 'Black'; Object = '[ERROR]' }) }
            elseif ($Failure) { $ColorText.Add(@{ BackgroundColor = 'Red';     ForegroundColor = 'Black'; Object = '[FAILURE]' }) }
            if ($Warning)     { $ColorText.Add(@{ BackgroundColor = 'Yellow';  ForegroundColor = 'Black'; Object = '[WARNING]' }) }
            if ($IsInfo)      { $ColorText.Add(@{ BackgroundColor = 'Green';   ForegroundColor = 'Black'; Object = '[INFO]' }) }
            if ($IsDebug)     { $ColorText.Add(@{ BackgroundColor = 'Cyan';    ForegroundColor = 'Black'; Object = '[DEBUG]' }) }
            if ($IsVerbose)   { $ColorText.Add(@{ BackgroundColor = 'Blue';    ForegroundColor = 'Black'; Object = '[VERBOSE]' }) }
            if ($WhatIfMode)  { $ColorText.Add(@{ BackgroundColor = 'Magenta'; ForegroundColor = 'Black'; Object = '[WHATIF]' }) }

            if ($Caller -and $Caller -ne '<ScriptBlock>') { $ColorText.Add( @{ Object = " $($Caller):" } ) }

            $ColorText.Add( @{ Object = " " } )
            if ($IsError) {
                $Info = $Object.InvocationInfo
                $ColorText.Add(@{ BackgroundColor = 'Black'; ForegroundColor = 'Red'; Object = " $Object" })
                $ColorText.Add(@{ Object = " at $($Info.ScriptName) line:$($Info.ScriptLineNumber) char:$($Info.OffsetInLine) " })
                $ColorText.Add(@{ BackgroundColor = 'Black'; ForegroundColor = 'White'; Object = $Info.Line.Trim() })
            }
            elseif ($Failure)     { $ColorText.Add(@{ ForegroundColor = 'Red';    Object = $Object; BackgroundColor = 'Black' }) }
            elseif ($Warning)     { $ColorText.Add(@{ ForegroundColor = 'Yellow'; Object = $Object }) }
            elseif ($DebugMode)   { $ColorText.Add(@{ ForegroundColor = 'Cyan';   Object = $Object }) }
            elseif ($VerboseMode) { $ColorText.Add(@{ ForegroundColor = 'Green';  Object = $Object }) }
            else                  { $ColorText.Add(@{ Object = $Object }) }

            foreach ($ColorItem in $ColorText) { Write-Host -NoNewLine @ColorItem }
            Write-Host # New line

            if ($Host.Name -eq 'RESPSHost') { # Ivanti Automation
                if (!$PSBoundParameters.ContainsKey('WriteActivity')) { # Explicitly enabled or disabled: -WriteActivity:$False
                    $DisableActivity = Get-ResParam -Name 'par_m_disable_activity' -ErrorAction SilentlyContinue
                    $Disabled = $False
                    if ([Boolean]::TryParse($DisableActivity, [ref]$Disabled)) { $WriteActivity = -not $Disabled }
                }
            }

            if ($Tee) { -Join $ColorText.Object }
            $Message = -Join $ColorText[1..99].Object # Skip the date/time
            if ($WriteActivity) { Write-Progress -Activity $Message }
            if ($WriteEvent) {
                $SourceExists = Try { [System.Diagnostics.EventLog]::SourceExists($EventSource) } Catch { $False }
                if (!$SourceExists) {
                    $WindowsIdentity =[System.Security.Principal.WindowsIdentity]::GetCurrent()
                    $WindowsPrincipal = [System.Security.Principal.WindowsPrincipal]::new($WindowsIdentity)
                    if ($WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        New-EventLog -LogName 'Application' -Source $EventSource
                        $SourceExists = Try { [System.Diagnostics.EventLog]::SourceExists($EventSource) } Catch { $False }
                    }
                    else {
                        SSO_WriteLog -Warning "The EventLog ""$EventSource"" should exist or administrator rights are required"
                    }
                }
                if ($SourceExists) {
                    if ($EventID -eq -1) {
                        $EventID = if ($Null -ne $Object) { "$Object".GetHashCode() -bAnd 0xffff } Else { 0 }
                    }
                    $EventType =
                        if     ($Category.HasFlag([EventFlag]::Error))   { 'Error' }
                        elseif ($Category.HasFlag([EventFlag]::Failure)) { 'Error' }
                        elseif ($Category.HasFlag([EventFlag]::Warning)) { 'Warning' }
                        else                                             { 'Information' }
                    Write-EventLog -LogName 'Application' -Source $EventSource -Category $Category -EventID $EventId -EntryType $EventType -Message $Message
                }
            }
            if ($Global:SSO_WriteLog[$Caller].Path) {
                Try { Add-Content -Path $Global:SSO_WriteLog[$Caller].Path -Value (-Join $ColorText.Object) }
                Catch { SSO_WriteLog -Warning "Can not write to logfile $FilePath" }
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -ne 'Legacy' -and !$MeAgain) {
            if (!$IsVerbose -and !$IsDebug) { WriteLog }
            elseif ($VerboseMode) { WriteLog }
            elseif ($DebugMode)   { WriteLog }
        }
    }
}
Set-Alias -Name Write-Log -Value SSO_WriteLog

enum MediaConnectState {
    Unknown
    Connected
    Disconnected
}

enum InterfaceOperationalStatus {
    Undefined
    Up
    Down
    Testing
    Unknown
    Dormant
    NotPresent
    LowerLayerDown
}

function Get-WiFiAdapter {
    Get-NetAdapter |Where-Object NdisPhysicalMedium -eq 9 # Native 802.11
}

function Get-StatusId {
    16 * $WiFiAdapter.MediaConnectState + $WiFiAdapter.InterfaceOperationalStatus
}

function Check-WiFiAdapter {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'MediaConnectState', Mandatory = $true)]
        [MediaConnectState[]]$MediaConnectState,

        [Parameter(ParameterSetName = 'InterfaceOperationalStatus', Mandatory = $true)]
        [InterfaceOperationalStatus[]]$InterfaceOperationalStatus,

        [Parameter(ParameterSetName = 'MediaConnectState')]
        [Parameter(ParameterSetName = 'InterfaceOperationalStatus')]
        $Timeout = $AdaperTimeout
    )
    $Seconds = 0
    while ($True) {
        if ($PSBoundParameters.ContainsKey('MediaConnectState') -and $MediaConnectState -eq [MediaConnectState]$WiFiAdapter.MediaConnectState) { return $True }
        if ($PSBoundParameters.ContainsKey('InterfaceOperationalStatus') -and $InterfaceOperationalStatus -eq [InterfaceOperationalStatus]$WiFiAdapter.InterfaceOperationalStatus) { return $True }
        if ($Seconds++ -ge $Timeout) { return $False }
        Wait-Event -TimeOut 1
        $WiFiAdapter = Get-WiFiAdapter
    }
}

$WiFiAdapter = Get-WiFiAdapter

if (!$WiFiAdapter) {
    Write-Log -Failure 'No Wi-Fi adapter found'
    return
}
elseif ($WiFiAdapter.Count -gt 1) {
    Write-Log -Warning @"

There are multiple Wi-Fi adapters available on this system:'
$($WiFiAdapter |Out-String)
Please supply the name of the adapter to be used.
E.g.: .\$(Split-Path $PSCommandPath -Leaf) -NetAdpaterName '$($WiFiAdapter[0].Name)'
"@
    return
}

if ($WiFiAdapter.MediaConnectState -eq 1) { # Connected
    Write-Log -Warning @"

The $($WiFiAdapter.Name) adapter is already connected.
If you process, the $($WiFiAdapter.Name) will be disconnected.
The script will automatically continue in $SecondsBeforeFirstDisable seconds
Press [Esc] to abort or any other key to continue
"@
    for ($i = 0; $i -lt $UserTimeout; $i++) {
        if ($Host.UI.RawUI.KeyAvailable) { break }
        Wait-Event -TimeOut 1
    }
    if ([System.Console]::ReadKey($true).Key -eq 'Escape') { return }
    $WiFiAdapter |Disable-NetAdapter -Confirm:$False
    Wait-Event -TimeOut 1
}

$WiFiAdapter |Enable-NetAdapter -Confirm:$False
if (!(Check-WiFiAdapter -MediaConnectState Disconnected, Connected)) { # Not Unknown
    Write-Log -EventId (Get-StatusId) -Failure "Could not not enable $($WiFiAdapter.Name)"
}

Connect-WiFiProfile -ProfileName govroam
if (Check-WiFiAdapter -InterfaceOperationalStatus Up) {
    Write-Log -EventId (Get-StatusId) 'Succesfully connected to govroam'
}
else {
    Write-Log -EventId (Get-StatusId) -Failure 'Could not connect to govroam'
}

# Schedule: https://stackoverflow.com/questions/20108886/powershell-scheduled-task-with-daily-trigger-and-repetition-interval

# $WiFiAdapter |Disable-NetAdapter -Confirm:$False
# if (!(Check-WiFiAdapter -MediaConnectState 'Unknown')) {
    # Write-Log -EventId (Get-StatusId) -Failure "Could not not disable $($WiFiAdapter.Name)"
# }


# Name                                   Value
# ----                                   -----
# Status                                 Disconnected
# LinkSpeed                              0 bps
# MediaConnectionState                   Disconnected
# ifOperStatus                           Down
# Speed
# FullDuplex                             True
# InterfaceOperationalStatus             2
# MediaConnectState                      2
# MediaDuplexState                       2
# OperationalStatusDownMediaDisconnected True
# ReceiveLinkSpeed
# TransmitLinkSpeed
# CimInstanceProperties                  {Caption, Description, ElementName, InstanceID...}

# Status                                 Up
# LinkSpeed                              173.3 Mbps
# MediaConnectionState                   Connected
# ifOperStatus                           Up
# Speed                                  173300000
# FullDuplex                             False
# InterfaceOperationalStatus             1
# MediaConnectState                      1
# MediaDuplexState                       1
# OperationalStatusDownMediaDisconnected False
# ReceiveLinkSpeed                       173300000
# TransmitLinkSpeed                      173300000
# CimInstanceProperties                  {Caption, Description, ElementName, InstanceID...}


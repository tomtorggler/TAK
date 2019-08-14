class IISLogEntry {
    [string]$date
    [string]$time
    [ipaddress]$sip
    [string]$csmethod
    [string]$csuristem
    [string]$csuriquery
    [string]$sport
    [string]$csusername
    [ipaddress]$cip
    [string]$csuseragent
    [string]$csreferer
    [string]$scstatus
    [string]$scsubstatus
    [string]$scwin32status
    [string]$timetaken

    IISLogEntry ([string]$line) {
        $this.date,$this.time,$this.sip,$this.csmethod,$this.csuristem,$this.csuriquery,$this.sport,$this.csusername,$this.cip,$this.csUserAgent,$this.csReferer,$this.scstatus,$this.scsubstatus,$this.scwin32status,$this.timetaken = $line -split " "
    }
}

function Import-IISLog {
    <#
    .SYNOPSIS
        Import IIS log files with default header.
    .DESCRIPTION
        This function imports IIS log files from CSV format.
    .EXAMPLE
        PS C:\> Import-IISLog
        Import the latest log found in the default log folder.
    .EXAMPLE
        PS C:\> Import-IISLog -Tail 10 -Wait
        Import the latest 10 lines of the latest log found in the default log folder and wait for new lines until stopped with ctrl-c.
    .INPUTS
        <none>
    .OUTPUTS
        [IISLogEntry]
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter()]    
        [string]
        $Path = "C:\inetpub\logs\LogFiles\*",
        [Parameter()]
        [string]
        $Filter = "*.log",
        [Parameter()]
        [int]
        $Tail = -1,
        [Parameter()]
        [switch]
        $Wait
    )   
    process {
        $Logs = Get-ChildItem -Path (Join-Path -Path $Path -ChildPath $Filter) -ErrorAction SilentlyContinue | Select-Object -Last 1
        Write-Information "FileName is $($Logs.fullname)" -InformationAction Continue
        $Logs | Get-Content -Tail $Tail -Wait:$wait.IsPresent | ForEach-Object {
            if($_ -notmatch "^#") {[IISLogEntry]::new($_)}
        }
    }
}

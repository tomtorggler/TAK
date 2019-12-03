function Import-DhcpServerLog {
    <#
    .SYNOPSIS
        Import DHCP Server Log files.
    .DESCRIPTION
        This function imports DHCP Server Log files from CSV format.
    .EXAMPLE
        PS C:\> Import-DhcpServerLog
        Import all logs found in the default log folder.
    .INPUTS
        <none>
    .OUTPUTS
        [psobject]
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        $Path = "C:\Windows\System32\dhcp",
        $Filter = "DhcpSrvLog*.log",
        $ComputerName,
        [switch]$Latest
    )   
    process {
        if($ComputerName){
            $Path = Join-Path -Path "\\$ComputerName" -ChildPath $Path.replace("C:","C$")
        }
        $csvHeader = @('ID','Date','Time','Description','IP Address','Host Name','MAC Address','User Name','TransactionID','QResult','Probationtime','CorrelationID','Dhcid','VendorClass(Hex)','VendorClass(ASCII)','UserClass(Hex)','UserClass(ASCII)','RelayAgentInformation','DnsRegError')
        Write-Verbose "Looking for files in $Path"
        $Logs = Get-ChildItem -Path (Join-Path -Path $Path -ChildPath $Filter) -ErrorAction SilentlyContinue
        if($Latest) {
            $logs = $Logs | Sort-Object LastWriteTime | Select-Object -Last 1
        }
        $Logs | Select-String -Pattern "\d{2}," | Select-Object -ExpandProperty Line | ConvertFrom-Csv -Header $csvHeader
    }
}

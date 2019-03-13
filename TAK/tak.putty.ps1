
function Add-PuttySession {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline,Mandatory)]
        [string]
        $Name,
        [Parameter()]
        [string]
        $HostName,
        [Parameter()]
        [switch]
        $Logging 
    )
    process {
        if(-not($HostName)){
            Write-Verbose "No HostName set, using $Name"
            $HostName = $Name
        }
        if($item = New-Item -Path HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions -Name $Name -ErrorAction SilentlyContinue){
            $prop = New-ItemProperty -Path $item.pspath -Name HostName -PropertyType String -Value $HostName     
            if($Logging) {
                $null = New-ItemProperty -Path $item.pspath -Name LogFileName -PropertyType String -Value "$Name.txt"
                $null = New-ItemProperty -Path $item.pspath -Name LogType -PropertyType DWord -Value 2
            }
        }
        Get-PuttySession -Name $Name
    }
}

function Get-PuttySession {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $Name = "*"
    )
    process {
        $Prop = @(
            "HostName",
            "PortNumber",
            "Protocol",
            "TerminalType",
            "LogType",
            "LogFileName"
        )
        Get-ItemProperty -Path "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\$Name" -Name $Prop -ErrorAction SilentlyContinue | 
            Select-Object -Property (@(@{n="Name";e={$_.PsChildName}}) + $Prop)
    }
}

function Remove-PuttySession {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        $Name
    )
    process {
        if ($pscmdlet.ShouldProcess($Name, "Remove Putty Session")) {
            Remove-Item -Path "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\$Name"
        }
    }
}

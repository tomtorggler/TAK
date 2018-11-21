function Convert-SubnetMask {
    <#
    .SYNOPSIS
        Convert a SubnetMask to PrefixLength or vice-versa.
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> Convert-SubnetMask 24
        255.255.255.0

        This example converts the PrefixLength 24 to a dotted SubnetMask.
    .EXAMPLE
        PS C:\> Convert-SubnetMask 255.255.0.0
        16

        This example counts the relevant network bits of the dotted SubnetMask 255.255.0.0.
    .INPUTS
        [string]
    .OUTPUTS
        [string]
    .NOTES
        Logic from: https://d-fens.ch/2013/11/01/nobrainer-using-powershell-to-convert-an-ipv4-subnet-mask-length-into-a-subnet-mask-address/
    #>
    [CmdletBinding()]
    param (
        # SubnetMask to convert
        [Parameter(Mandatory)]
        $SubnetMask
    )
    if($SubnetMask -as [int]) {
        [ipaddress]$out = 0
        $out.Address = ([UInt32]::MaxValue) -shl (32 - $SubnetMask) -shr (32 - $SubnetMask)
        $out.IPAddressToString
    } elseif($SubnetMask = $SubnetMask -as [ipaddress]) {
        $SubnetMask.IPAddressToString.Split('.') | ForEach-Object {
            while(0 -ne $_){
                $_ = ($_ -shl 1) -band [byte]::MaxValue
                $result++
            }
        }
        $result -as [string]
    }
}
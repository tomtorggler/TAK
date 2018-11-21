function Get-DKIMRecord {
    <#
    .SYNOPSIS
        Get DKIM Record for a domain.
    .DESCRIPTION
        This function uses Resolve-DNSName to get the SPF Record for a given domain. Objects with a DomainName property,
        such as returned by Get-AcceptedDomain, can be piped to this function.
    .EXAMPLE
        Get-AcceptedDomain | Get-DKIMRecord

        This example gets DKIM records for all domains returned by Get-AcceptedDomain.
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Get-DKIMRecord/')]
    param (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true)]
        [string]
        $DomainName,
        [Parameter(Mandatory=$true)]
        [string[]]
        $Selector,
        [string]
        $Server
    )
    process {
        foreach ($S in $Selector) {
            $params = @{
                Name = "$s._domainkey.$DomainName"
                ErrorAction = "SilentlyContinue"
            }
            if($Server) { $params.Add("Server",$Server) }
            # Resovle
            $dnsTxt = Resolve-DnsName @params -Type TXT | Where-Object Type -eq TXT  
            $dnsTxt | Select-Object @{Name = "DKIM"; Expression = {"$DomainName`:$s"}},@{Name = "Record"; Expression = {$_.Strings}}    
        }
    }    
}
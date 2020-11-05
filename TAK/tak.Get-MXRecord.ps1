function Get-MxRecord {
    <#
    .SYNOPSIS
        Get MX Records for a domain.
    .DESCRIPTION
        Uses Resolve-DnsName to get MX Records, Priority and the IP Address of the records.
    .EXAMPLE
        PS C:\> Get-MxRecord ntsystems.it
        
        This example gets the MX record for the domain ntsystems.it.
    .INPUTS
        [string]
    .OUTPUTS
        [Selected.Microsoft.DnsClient.Commands.DnsRecord_MX]
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Get-MxRecord/')]
    param (
        # Specify the Domain name for the query.
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias("DomainName")]
        [string]
        $Domain,

        # Specify the DNS server to query.
        [System.Net.IPAddress]
        $Server,

        # Also resolve PTR
        [switch]
        $ResolvePTR
    )
    begin {
        $param = @{
            ErrorAction="SilentlyContinue"
        }
        if($Server) {
            $param.Add("Server",$Server)
        }
    }
    process {
        $mx = Resolve-DnsName -Name $domain -Type MX -ErrorAction SilentlyContinue | Where-Object Type -eq "MX"
        if ($mx) {
            $rec = $mx | Select-Object -Property Name,NameExchange,Preference,@{
                    Name = "IPAddress" 
                    Expression = {
                        Resolve-DnsName -Name $_.NameExchange -Type A_AAAA @param | Select-Object -ExpandProperty IPAddress    
                    }
                }
            $rec | Select-Object -Property *,@{
                Name = "PTR"
                Expression = {
                    $_.IpAddress | ForEach-Object {
                        if($ResolvePTR){
                            Resolve-DnsName -Name $_ -Type PTR @param | Select-Object -ExpandProperty NameHost    
                        }
                    }
                }
            }
        }
    }
}
function Get-IntuneRecords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ValueFromPipeline=$true)]
        [string]
        $DomainName
    )
    
    begin {
        
    }
    
    process {
        foreach($domain in $DomainName){
            $reg = Resolve-DnsName "enterpriseregistration.$domain" -Type CNAME -ea 0 | where Type -eq "CNAME" #Where-Object {$_ -isnot [Microsoft.DnsClient.Commands.DnsRecord_SOA]}
            $enrol = Resolve-DnsName "enterpriseenrollment.$domain" -Type CNAME -ea 0 | where Type -eq "CNAME" #Where-Object {$_ -isnot [Microsoft.DnsClient.Commands.DnsRecord_SOA]}
            New-Object -TypeName psobject -Property ([ordered]@{
                DomainName = $domain
                #ER = $reg.Name
                ERTarget = $reg.NameHost
                #EE = $enrol.Name
                EETarget = $enrol.NameHost
            })
        }
        
    }
    
    end {
        
    }
}
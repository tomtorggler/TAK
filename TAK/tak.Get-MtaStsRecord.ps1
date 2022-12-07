function Get-MtaStsRecord {
    <#
    .SYNOPSIS
        Get DMARC Record for a domain.
    .DESCRIPTION
        This function uses Resolve-DNSName to get the DMARC Record for a given domain. Objects with a DomainName property,
        such as returned by Get-AcceptedDomain, can be piped to this function.
    .EXAMPLE
        Get-AcceptedDomain | Get-DMARCRecord

        This example gets DMARC records for all domains returned by Get-AcceptedDomain.
    #>
    [CmdletBinding(HelpUri = 'https://onprem.wtf/PowerShell/TAK/Get-DMACRecord/')]
    param (
        # Specify the Domain name to use for the query.
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true)]
        [string]
        $DomainName,
        
        # Specify a DNS server to query.
        [string]
        $Server
    )
    process {    
        $params = @{
            Name = "_mta-sts.$DomainName"
            ErrorAction = "SilentlyContinue"
        }
        if($Server) { $params.Add("Server",$Server) }
        $dnsTxt = Resolve-DnsName @params -Type  TXT | Where-Object Type -eq TXT  
        New-Object -TypeName psobject -Property ([ordered]@{
            DomainName = $DomainName
            Record = $dnsTxt.Strings
        }) 
    }    
}


function Get-MtaStsFile {
    <#
    .SYNOPSIS
        Get DMARC Record for a domain.
    .DESCRIPTION
        This function uses Resolve-DNSName to get the DMARC Record for a given domain. Objects with a DomainName property,
        such as returned by Get-AcceptedDomain, can be piped to this function.
    .EXAMPLE
        Get-AcceptedDomain | Get-DMARCRecord

        This example gets DMARC records for all domains returned by Get-AcceptedDomain.
    #>
    [CmdletBinding(HelpUri = 'https://onprem.wtf/PowerShell/TAK/Get-DMACRecord/')]
    param (
        # Specify the Domain name to use for the query.
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true)]
        [string]
        $DomainName
    )
    process {    
        $params = @{
            uri = "https://mta-sts.$DomainName/.well-known/mta-sts.txt"
            ErrorAction = "SilentlyContinue"
        }
        $result = Invoke-WebRequest @params
        New-Object -TypeName psobject -Property ([ordered]@{
            DomainName = $DomainName
            Record = $result.content
        }) 
    }    
}

function Get-SmtpTlsRecord {
    <#
    .SYNOPSIS
        Get DMARC Record for a domain.
    .DESCRIPTION
        This function uses Resolve-DNSName to get the DMARC Record for a given domain. Objects with a DomainName property,
        such as returned by Get-AcceptedDomain, can be piped to this function.
    .EXAMPLE
        Get-AcceptedDomain | Get-DMARCRecord

        This example gets DMARC records for all domains returned by Get-AcceptedDomain.
    #>
    [CmdletBinding(HelpUri = 'https://onprem.wtf/PowerShell/TAK/Get-DMACRecord/')]
    param (
        # Specify the Domain name to use for the query.
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true)]
        [string]
        $DomainName,
        
        # Specify a DNS server to query.
        [string]
        $Server
    )
    process {    
        $params = @{
            Name = "_smtp._tls.$DomainName"
            ErrorAction = "SilentlyContinue"
        }
        if($Server) { $params.Add("Server",$Server) }
        $dnsTxt = Resolve-DnsName @params -Type  TXT | Where-Object Type -eq TXT  
        New-Object -TypeName psobject -Property ([ordered]@{
            DomainName = $DomainName
            Record = $dnsTxt.Strings
        }) 
    }    
}

function New-MtaTlsReport {
    param($domain)
    New-Object -TypeName psobject -Property ([ordered]@{
        Domain = $domain
        STSRecord = (Get-MtaStsRecord -DomainName $domain).Record -join ""
        SMTPTls = (Get-SmtpTlsRecord -DomainName $domain).Record -join ""
        MTAFile = (Get-MtaStsFile -DomainName $domain).Record
    })
}

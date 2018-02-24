#region Helpers

function New-ExchangeAutodiscoverReport {
    [CmdletBinding()]
    param (
        [psobject]
        $InputObject,
        [System.IO.FileInfo]
        $FileName = (Join-Path -Path $($env:temp) -ChildPath "ExchangeAutodiscoverReport.html")
    )
    
    begin {
        Remove-Item -Path $FileName -ErrorAction SilentlyContinue
    }
    
    process {
        foreach($key in (Get-Member -InputObject $InputObject -MemberType NoteProperty).Name) {
            $html += $InputObject.$key.Protocol | ConvertTo-Html -As List -Fragment
        }
        $html | Set-Content -Path $FileName
        Write-Host "report at $FileName"
    }
    
    end {
    }
}

function Get-XmlBody([string]$EmailAddress){
[xml]@"
    <Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/requestschema/2006">
    <Request>
        <EMailAddress>$EmailAddress</EMailAddress>
        <AcceptableResponseSchema>http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a</AcceptableResponseSchema>
    </Request>
    </Autodiscover>
"@
}

function Get-AutodiscoverURI {
    param (
        [string]$EmailAddress,
        [string]$ComputerName,
        [switch]$ExcludeExplicitO365Endpoint
    )
    $domainName = $EmailAddress -split "@" | Select-Object -Last 1
    $out = @{
        "root" = "https://$domainName/autodiscover/autodiscover.xml";
        "autodiscover" = "https://autodiscover.$domainName/autodiscover/autodiscover.xml";
    }
    
    if($adSrv = Get-AutodiscoverSRV -domainName $domainName) {
        $out.Add("srv",$adSrv)
    }
    
    if($ComputerName) {
        $out.Add("uri","https://$ComputerName/autodiscover/autodiscover.xml")
    }
    
    if (-not($ExcludeExplicitO365Endpoint)) {
        $out.Add("o365","https://autodiscover-s.outlook.com/autodiscover/autodiscover.xml")
    }

    $out
}

function Get-AutodiscoverResponse {
    [CmdletBinding()]
    param(
        [string]$uri,
        [xml]$body,
        [int]$Timeout = 2,
        [pscredential]$Credential
    )
    $params = @{
        "uri" = $uri 
        "Credential" = $Credential
        "Method" = "post" 
        "Body" = $body 
        "Headers" = @{"content-type"="text/xml"} 
        "DisableKeepAlive" = $true
        "TimeoutSec" = $Timeout
    }
    try {
        Write-Verbose "Trying to connect to $uri"
        $adPayload = Invoke-RestMethod @params
        $adPayload.Autodiscover.Response.Account         
    } catch {
        Write-Verbose "Could not connect to $uri"
    }
}   

function Get-AutodiscoverSRV([string]$domainName) {
    $dns = Resolve-DnsName -Name "_autodiscover._tcp.$domainName" -Type SRV -ErrorAction SilentlyContinue | Where-Object {$_.Type -eq "SRV" -and $_.Port -eq 443}
    if($dns) {
        "https://$($dns.NameTarget)/autodiscover/autodiscover.xml"
    }
}
#endregion Helpers

#region Exchange

function Test-ExchangeAutodiscover {
    <#
    .SYNOPSIS
        Test Exchange Autodiscover Web Service.
    .DESCRIPTION
        This function tests the Exchange Autodiscover Web Serivce for a given Emailaddress. If ComputerName is not specified,
        the function tries to look up the Autodiscover service using the Outlook Clients logic. Locally cached and SCP data
        are not evaluated.
    .EXAMPLE
        PS C:\> Test-ExchangeAutodiscover thomas@ntsystems.it -Credential (Get-Credential)
        
        This example tests the Autodiscover service for the given mailbox. It will query dns for autodiscover.ntsystems.it and _autodiscover._tcp.ntsystems.it. 
        It will then try to retrieve an Autodiscover payload from https://ntsystems.it, https://autodiscover.ntsystems.it and the Office 365 endpoint.
    .OUTPUTS
        [psobject]
    #>    
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/test-exchangeautodiscover/')]
    param (
        [string]
        $EmailAddress,
        [string]
        $ComputerName,
        [pscredential]
        $Credential,
        [switch]
        $ExcludeExplicitO365Endpoint,
        [System.IO.FileInfo]
        $Report
    )
    
    begin {
        # Get URI and XML Body for reuqest
        $adURIs = Get-AutodiscoverURI @PSBoundParameters
        $body = Get-XMLBody @PSBoundParameters
    }
    
    process {
        # Create an empty dictionary to store 
        $out = @{}
        foreach($key in $adURIs.keys){
            Write-Verbose "Testing $key domain for $EmailAddress : $($adURIs[$key])"
            $r = Get-AutodiscoverResponse -uri $adURIs[$key] -Credential $Credential -body $body
            if($r) {
                $out.add($key,$r)
            }
        }
        # create a new object and write it to the pipeline
        $global:ExchangeAutodiscoverResults = New-Object -TypeName psobject -Property $out | Add-Member -TypeName 'System.TAK.ExchangeAutoDiscover' -PassThru
        Write-Output $global:ExchangeAutodiscoverResults
        
        Write-Host "Results are available through the global variable `$ExchangeAutodiscoverResults for your convenience.`n"

        if($Report) {
            New-ExchangeAutodiscoverReport -InputObject $global:ExchangeAutodiscoverResults -FileName $Report
        }

    }
    
    end {
    }
}

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
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/get-mxrecord/')]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $Domain
    )
    process {
        $mx = Resolve-DnsName -Name $domain -Type MX -ErrorAction SilentlyContinue | Where-Object Type -eq "MX"
        if ($mx) {
            $mx | Select-Object -Property NameExchange,Preference,@{
                Name = "IPAddress" 
                Expression = { 
                    Resolve-DnsName -Name $_.NameExchange -Type A_AAAA | Select-Object -ExpandProperty IPAddress
                }
            }
        }
    }
}

#endregion 


#region Test ADFS

function Test-FederationService {
    <#
    .Synopsis
       Test the ADFS web service
    .DESCRIPTION
       This function uses Invoke-RestMethod to test if the federation service metadata can be retrieved from a given server.
    .EXAMPLE
       Test-FederationService -ComputerName fs.uclab.eu 
       This example gets federation service xml information over the server fs.uclab.eu
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Test-FederationService/')]
    param(
        # Specifies the name of the federation server 
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        [Alias("Server")]
        $ComputerName
    )

    $uri = "https://$ComputerName/FederationMetadata/2007-06/FederationMetadata.xml"
    # "adfs/ls/idpinitiatedsignon.htm"
    try {
        $webRequest = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        Write-Verbose $webRequest
    } catch {
        Write-Warning "Could not connect to $uri error $_"
        return
    }
    $out = [ordered]@{
        "entityID" = $webRequest.entitydescriptor.entityID
        "xmlns" = $webRequest.entitydescriptor.xmlns
        "Roles" = @{
            "type" = $webRequest.entitydescriptor.RoleDescriptor.type
            "ServiceDisplayName" = $webRequest.entitydescriptor.RoleDescriptor.ServiceDisplayName
        }
    }
    # Create a custom object and add a custom TypeName for formatting before writing to pipeline
    Write-Output (New-Object -TypeName psobject -Property $out) 
}
#endregion Test ADFS

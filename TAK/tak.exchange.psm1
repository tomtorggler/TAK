#region Helpers

function Get-AutoDiscoverDns {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]    
        $DomainName
    )
    process {
        foreach ($d in $DomainName) {
            
            $A = Resolve-DnsName -Name "autodiscover.$d" -ErrorAction SilentlyContinue -Type A | Where-Object {$_ -isnot [Microsoft.DnsClient.Commands.DnsRecord_SOA]}
            $SRV = Resolve-DnsName -Name "_autodiscover._tcp.$d" -Type SRV -ErrorAction SilentlyContinue | Where-Object {$_.Type -eq "SRV" -and $_.Port -eq 443}

            $out = [ordered]@{
                Domain = $d
                IPAddress = $a.IpAddress
                Type = $null
                SRV = $SRV.NameTarget
            }
    
            if($a.count -gt 1){
                $out.Type = $a[0].Type
            } else {
                $out.Type = $a.Type
            }

            New-Object -TypeName psobject -Property $out
        }
    }
}


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
        [int]$Timeout = 4,
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

function Get-AutodiscoverSRV {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $DomainName
    )
    process{
        $dns = Resolve-DnsName -Name "_autodiscover._tcp.$domainName" -Type SRV -ErrorAction SilentlyContinue | Where-Object {$_.Type -eq "SRV" -and $_.Port -eq 443}
        if($dns) {
            "https://$($dns.NameTarget)/autodiscover/autodiscover.xml"
        }
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

    [byte[]]$rawData = [System.Convert]::FromBase64String($webRequest.EntityDescriptor.Signature.KeyInfo.X509Data.X509Certificate)
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.Import($rawData)
    
    $out = [ordered]@{
        "entityID" = $webRequest.entitydescriptor.entityID
        "xmlns" = $webRequest.entitydescriptor.xmlns
        "Roles" = @{
            "type" = $webRequest.entitydescriptor.RoleDescriptor.type
            "ServiceDisplayName" = $webRequest.entitydescriptor.RoleDescriptor.ServiceDisplayName
        }
        "IDPSSODescriptor" = $webRequest.EntityDescriptor.IDPSSODescriptor
        "SPSSODescriptor" = $webRequest.EntityDescriptor.SPSSODescriptor
        "SigningCert" = $certificate

    }
    # Create a custom object and add a custom TypeName for formatting before writing to pipeline
    Write-Output (New-Object -TypeName psobject -Property $out) 
}
#endregion Test ADFS


#region SPF
function New-SPFRecord {
    <#
    .SYNOPSIS
        Create SPF record for a given mail domain.
    .DESCRIPTION
        This function helps with creating SPF records for mail domains.
        The SPF record should look something like this:

        v=spf1 mx a ptr ip4:127.1.1.1/24 a:host.example.com include:example.com -all

        More information: https://www.ietf.org/rfc/rfc4408.txt
    .EXAMPLE
        PS C:\> Get-AcceptedDomain | New-SPFRecord -mx -IncludeDomain spf.protection.outlook.com -IncludeIP 192.0.2.1,2001:DB8::1 -Action Fail

        DomainName : uclab.eu
        Record     : "v=spf1 mx ip4:192.0.2.1 ip6:2001:DB8::1 include:spf.protection.outlook.com -all"

        The above example creates SPF records for all accepted domains in Exchange (Online).
    .INPUTS
        [string]
        [AcceptedDomain]

        This function accepts a string or objects with a DomainName property (such as returned by Get-AcceptedDomain) as input.
    .OUTPUTS
        [psobject]

        This function writes a custom object to the pipeline.
    .NOTES
        Author: @torggler
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/New-SPFRecord/')]
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true)]
        [string]
        $DomainName,
        [switch]
        $mx,
        [switch]
        $a,
        [switch]
        $ptr,
        [ipaddress[]]
        $IncludeIP,
        [string]
        $IncludeDomain,
        [string]
        $IncludeHost,
        [ValidateSet("Fail","SoftFail","Neutral")]
        [string]
        $Action = "Fail"
    )   
    process {
        # if run without parameters, set mx to default
        if(-not($PSBoundParameters.Count)) {
            $PSBoundParameters.Add("mx",$true)
            $PSBoundParameters.Add("Action","Fail")
        }

        Write-Verbose "Creating SPF for domain $DomainName"

        $spfBase = "v=spf1"

        switch ($PSBoundParameters.Keys) {
            "mx" { $spfMX = "mx" }
            "ptr" { $spfPTR = "ptr" }
            "a" { $spfA = "a" }
            "IncludeIP" { 
                $i = 0 # use a little counter to avoid inserting unnecessary spaces 
                foreach ($ip in $IncludeIP) {
                    switch ($ip.AddressFamily) {
                        InterNetwork { 
                            Write-Verbose "adding ip4 $ip"
                            if($i -eq 0) {
                                $spfIP = "ip4:$($ip.IPAddressToString)" 
                            } else {
                                $spfIP += " ip4:$($ip.IPAddressToString)" 
                            }
                        }
                        InterNetworkV6 { 
                            Write-Verbose "adding ip6 $ip"
                            if($i -eq 0) {
                                $spfIP = "ip6:$($ip.IPAddressToString)"
                            } else {
                                $spfIP += " ip6:$($ip.IPAddressToString)" 
                            }
                        }
                    }
                $i++
                }
            }
            "IncludeDomain" {
                Write-Verbose "adding include:$IncludeDomain"
                $spfDomain = "include:$IncludeDomain"
            }
            "IncludeHost" {
                Write-Verbose "adding include:$IncludeHost"
                $spfHost = "a:$IncludeHost"
            }
            "Action" {
                switch($Action) {
                    "Fail" { 
                        Write-Verbose "Setting action to Fail"
                        $spfAction = "-all" 
                    }
                    "SoftFail" {
                        Write-Verbose "Setting action to SoftFail"
                        $spfAction = "~all"
                    }
                    "Neutral" { 
                        Write-Verbose "Setting action to Neutral"
                        $spfAction = "?all" 
                    }
                }
            }
        }
        $Record = $spfBase,$spfMX,$spfA,$spfPTR,$spfIP,$spfDomain,$spfHost,$spfAction | Where-Object {$_}
        New-Object -TypeName psobject -Property ([ordered]@{
            DomainName = $DomainName
            Record = $Record -join " "
        })        
    }
}


#endregion SPF
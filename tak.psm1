﻿#region Test Connection
function Test-TLSConnection {
    <#
    .Synopsis
       Test if TLS Connection can be established.
    .DESCRIPTION
       This function uses System.Net.Sockets.Tcpclient and System.Net.Security.SslStream to connect to a ComputerName and 
       authenticate via TLS. This is useful to check if a TLS connection can be established and if the certificate used on 
       the remote computer is trusted on the local machine.
       If the connection can be established, the certificate's properties will be output as custom object.
       Optionally the certificate can be downloaded using the -SaveCert switch.
    .EXAMPLE
       Test-TlsConnection -ComputerName www.ntsystems.it
       This example connects to www.ntsystems.it on port 443 (default) and outputs the certificate's properties.
    .EXAMPLE
       Test-TlsConnection -ComputerName sipdir.online.lync.com -Port 5061 -SaveCert 
       This example connects to sipdir.online.lync.com on port 5061 and saves the certificate to the temp folder.
    #>
    [CmdletBinding(HelpUri = 'http://www.ntsystems.it/')]
    [Alias('ttls')]
    [OutputType([psobject],[bool])]
    param (
        [Parameter(Mandatory=$true, 
                    Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("HostName","Server","RemoteHost")] 
        $ComputerName,

        [Parameter(Mandatory=$false, 
                    Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("RemotePort")]    
        [ValidateRange(1,65535)]
        $Port = '443',

        [Parameter(Mandatory=$false, 
                    Position=2)]
        [System.IO.FileInfo]
        $FilePath = "$env:TEMP\$computername.cer",
        
        [switch]
        $SaveCert,

        [switch]
        $Silent
    )

    try {
        $TCPConnection = New-Object System.Net.Sockets.Tcpclient($ComputerName, $Port)

        Write-Verbose "TCP connection has succeeded"

        $TCPStream     = $TCPConnection.GetStream()

        try {
            $SSLStream = New-Object System.Net.Security.SslStream($TCPStream)
            Write-Verbose "SSL connection has succeeded"
            
            try {
                $SSLStream.AuthenticateAsClient($ComputerName)
                Write-Verbose "SSL authentication has succeeded"
            } catch {
                Write-Warning "There's a problem with SSL authentication to $ComputerName `n$_"
                return $false
            }

            $certificate = $SSLStream.get_remotecertificate()
            $certificateX509 = New-Object system.security.cryptography.x509certificates.x509certificate2($certificate)
            $SANextensions = New-Object system.security.cryptography.x509certificates.x509Certificate2Collection($certificateX509)
            $SANextensions = $SANextensions.Extensions | Where-Object {$_.Oid.FriendlyName -eq "subject alternative name"}

            $data = [ordered]@{
                'ComputerName'=$ComputerName;
                'Port'=$Port;
                'Issuer'=$SSLStream.RemoteCertificate.Issuer;
                'Subject'=$SSLStream.RemoteCertificate.Subject;
                'SerialNumber'=$SSLStream.RemoteCertificate.GetSerialNumberString();
                'ValidTo'=$SSLStream.RemoteCertificate.GetExpirationDateString();
                'SAN'=$SANextensions.Format(1);
            }

            if($Silent) {
                Write-Output $true
            } else {
                Write-Output (New-Object -TypeName PSObject -Property $Data)
            }

            if ($SaveCert) {
                Write-Host "Saving cert to $FilePath" -ForegroundColor Yellow
                [system.io.file]::WriteAllBytes($FilePath,$certificateX509.Export("cer"))
            }

        } catch {
            Write-Warning "$ComputerName doesn't support SSL connections at TCP port $Port `n$_"
        }

    } catch {

        $exception = New-Object system.net.sockets.socketexception
        $errorcode = $exception.ErrorCode

        Write-Warning "TCP connection to $ComputerName with IP $(([net.dns]::GetHostByName($ComputerName)).addresslist.ipaddresstostring) failed, error code:$errorcode"
        Write-Warning "Error details: $exception"    
    }
}

function Test-TCPConnection {
    <#
    .Synopsis
       Test if a TCP Connection can be established.
    .DESCRIPTION
       This function uses System.Net.Sockets.Tcpclient to test if a TCP connection can be established with a 
       ComputerName on a given port. Much like "telnet" which is not installed by default.
    .EXAMPLE
       Test-TcpConnection -ComputerName www.ntsystems.it
       This example tests if port 80 can be reached on www.ntsystems.it
    .EXAMPLE
       Test-TcpConnection -ComputerName www.ntsystems.it -Port 25 -Count 4
       This example tests for 4 times if port 25 can be reached on www.ntsystems.it
    #>
    [CmdletBinding(HelpUri = 'http://www.ntsystems.it/')]
    [Alias('ttcp')]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true, 
                    Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("HostName","Server","RemoteHost")] 
        $ComputerName,

        [Parameter(Mandatory=$false, 
                    Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("RemotePort")]    
        [ValidateRange(1,65535)]
        $Port = '80',

        [int]
        $Count = 1
    )

    for ($i = 0; $i -lt $Count; $i++)
    { 
        $TCPConnection = New-Object System.Net.Sockets.Tcpclient
        Try { 
            $TCPConnection.Connect($ComputerName, $Port) 
        } Catch {
            Write-Verbose "Error connecting to $ComputerName on $Port : $_"
        }

        If ($?) {
            Write-Output $True
            $TCPConnection.Close()
        } else {
            Write-Output $false
        }
        $TCPConnection.Dispose()
    }
}
#endregion Test Connection

#region Test Lync deployment
function Test-LyncDNS {
    <#
    .Synopsis
       Test DNS entries for Lync deployments.
    .DESCRIPTION
       This function uses Resolve-DnsName to query well-known DNS records for Lync deployments.
       The NameSever parameter can be used to specify a nameserver.
    .EXAMPLE
       Test-LyncDNS -SipDomain uclab.eu
       This example queries DNS records for the domain uclab.eu
    #>
    
    [CmdletBinding()]
    
    param(
        # specify the domain name
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        $SipDomain,

        # specify the nameserver to query
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [Alias("Server")]
        [ipaddress]
        $NameServer,
        
        # use opendns server
        [switch]
        $OpenDNS,
        
        # also query for internal records
        [switch]
        $internal,
        
        # test tls connection to servers
        [switch]
        $testConnection
    )

    if ($NameServer) {
        $rdnsCmd = @{
            "ErrorAction"="SilentlyContinue";
            "Server"="$NameServer"
            "DnsOnly"=$true
        }
        Write-Verbose "using Nameserver $NameServer"
    } elseif ($openDNS) {
        $rdnsCmd = @{
            "ErrorAction"="SilentlyContinue";
            "Server"="208.67.222.222";
            "DnsOnly"=$true
        }
        Write-Verbose "using OpenDS Nameserver $NameServer"
    } else {
        $rdnsCmd = @{
            "ErrorAction"="SilentlyContinue";
            "DnsOnly"=$true
        }    
        Write-Verbose "using default Nameserver"
    }
    
    # define arrays 
    $srvRecords = @()
    $aRecords = @()

    $srvRecords += Resolve-DnsName -Type SRV -Name "_sipfederationtls._tcp.$SipDomain" @rdnsCmd
    $srvRecords += Resolve-DnsName -Type SRV -Name "_sip._tls.$SipDomain" @rdnsCmd
    $srvRecords += Resolve-DnsName -Type SRV -Name "_xmpp-server._tcp.$SipDomain" @rdnsCmd
    
    # some a record names may be defined in the topology and therefore be different 
    $aRecords += Resolve-DnsName -Type A -Name "LyncDiscover.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "LyncWeb.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "meet.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "join.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "dialin.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "sipexternal.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "webconf.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "sip.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "av.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "avedge.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "dataedge.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "sipedge.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "ucupdates-r2.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "autodiscover.$SipDomain" @rdnsCmd
    $aRecords += Resolve-DnsName -Type A -Name "owc.$SipDomain" @rdnsCmd
    
    # query domain root record to filter wildcard matches
    $rootRecord = Resolve-DnsName -Type A -Name "$SipDomain" @rdnsCmd
    
    if($internal) {
        $srvRecords += Resolve-DnsName -Type SRV -Name "_sipinternaltls._tcp.$SipDomain" @rdnsCmd
        $aRecords += Resolve-DnsName -Type A -Name "LyncDiscoverInternal.$SipDomain" @rdnsCmd    
        $aRecords += Resolve-DnsName -Type A -Name "sipinternal.$SipDomain" @rdnsCmd 
    }
    
    $aRecords += $srvRecords | Where-Object {$PSItem -is [Microsoft.DnsClient.Commands.DnsRecord_A]} 
    
    $srvRecords | Where-Object {$PSItem -is [Microsoft.DnsClient.Commands.DnsRecord_SRV]}
    $aRecords | Where-Object {$PSItem.IpAddress -ne $rootRecord.IP4Address -and $PSItem.Section -eq "Answer"}

    if($testConnection) {
        $aRecords | ForEach-Object {
            Write-Verbose "Testing TLS connection for $($_.Name)"
            Test-TLSConnection -ComputerName $_.Name -Silent
        }
        $srvRecords | ForEach-Object {
            Write-Verbose "Testing TLS connection for $($_.Name):$($_.Port)"
            Test-TLSConnection -ComputerName $_.NameTarget -Port $_.Port -Silent
        }
    }
}

function Test-LyncDiscover {
    <#
    .Synopsis
       Test Lyncdiscover service
    .DESCRIPTION
       This function uses Invoke-WebRequest to test if the Lyncdiscover service is responding for a given domain.
    .EXAMPLE
       Test-LyncDiscover -SipDomain uclab.eu -Http
       This example gets Lyncdiscover information over http for the domain uclab.eu
    #>

    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        $SipDomain,
        
        [switch]
        $Http,
        
        [switch]
        $internal
    )

    if($Http){
        $uriPrefix = "http://"
    } else {
        $uriPrefix = "https://"
    }

    if($internal){
        $uriHost = "lyncdiscoverinternal"
    } else {
        $uriHost = "lyncdiscover"
    }

    $uri = $uriPrefix + $uriHost + "." + $SIPDomain
    try {
        $webRequest = Invoke-WebRequest -Uri $uri -ErrorAction Stop
        Write-Verbose $webRequest
    } catch {
        Write-Warning "Could not connect to $uri error $_"
        return
    }
    if($webRequest.Headers.'Content-Type' -like 'application/json') {
        $json = ConvertFrom-Json -InputObject $webRequest.Content
    } else {
        $json = ConvertFrom-Json -InputObject ([System.Text.Encoding]::ASCII.GetString($webRequest.Content))    
    }

    $json.AccessLocation
    $json.Root.Links
    $json._links
}
#endregion Test Lync deployment

#region EtcHosts
function Show-EtcHosts {
    <#
    .Synopsis
       Display \etc\hosts file content.
    .DESCRIPTION
       This funtion gets the content of the hosts file, parses the lines and outputs 
       a custom object with HostName and IPAddress properties.
    #>

    [Alias('shosts')]
    [OutputType([psobject])]

    # filter out comments and empty lines
    $lines = Get-Content (Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts) | Where-Object {$PSItem -notmatch "^#" -and $PSItem -ne ""}
        if ($lines){        # Split the content of $lines        $linesSplit = $lines -split '\s+'            
        # looping through the array, create key:value pairs and add them to $outData
        for ($i = 0; $i -lt $linesSplit.Count; $i++) {
            if ([bool]!($i%2)) {
                $j = $i + 1 
                $outData = @{'IPAddress'=$linesSplit[$i];'HostName'=$linesSplit[$j]}
                                # create custom object and write it to the pipeline                Write-Output (New-Object -TypeName psobject -Property $outData)
            }
        }    }
}

function Edit-EtcHosts {
    <#
    .Synopsis
       Edit \etc\hosts file with notepad.
    .DESCRIPTION
       This funtion starts notepad.exe as administrator and opens the hosts file for editing.
    #>
    # run notepad as administrator and open the hosts file for editing
    Start-Process notepad -Verb RunAs -ArgumentList (Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts)
}
#endregion EtcHosts

#region PS Sessions
function Connect-Exchange
{
    [CmdletBinding()]
    Param
    (
        # Servername that the session will be connected to
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Server,

        # Credential used for connection; if not specified, the currently logged on user will be used 
        [pscredential]
        $Credential
    )
    if ((Get-PSSession).ConfigurationName -ne "Microsoft.Exchange" -and $Credential) {
        $params = @{
            ConfigurationName = "Microsoft.Exchange";
            Name = "ExchMgmt";
            Authentication = "Kerberos";
            Credential = $Credential;
            ConnectionUri = "http://$Server/PowerShell/"
        }
    } elseif ((Get-PSSession).ConfigurationName -ne "Microsoft.Exchange" -and (-not $Credential)) {
        $params = @{
            ConfigurationName = "Microsoft.Exchange";
            Name = "ExchMgmt";
            Authentication = "Kerberos";
            ConnectionUri = "http://$Server/PowerShell/"
        }
    } else {
        Write-Warning "Already connected to Exchange"
        break
    }
    try {
        $sExch = New-PSSession @params -ErrorAction Stop -ErrorVariable ExchangeSessionError
	    Import-PSSession $sExch
    } catch {
        Write-Warning "Could not connect to Exchange $($ExchangeSessionError.ErrorRecord)"
    }
} 

function Connect-Lync
{
    [CmdletBinding()]
    Param
    (
        # Servername that the session will be connected to
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Server,

        # Credential used for connection; if not specified, the currently logged on user will be used 
        [pscredential]
        $Credential
    )
    if ((Get-PSSession).Name -ne "LyncMgmt" -and $Credential) {
        $params = @{
            Name = "LyncMgmt";
            Authentication = "Negotiate";
            Credential = $Credential;
            ConnectionUri = "http://$Server/ocsPowerShell/"
        }
    } elseif ((Get-PSSession).Name -ne "LyncMgmt" -and (-not $Credential)) {
        $params = @{
            Name = "LyncMgmt";
            Authentication = "Negotiate";
            ConnectionUri = "http://$Server/ocsPowerShell/"
        }
    } else {
        Write-Warning "Already connected to Lync"
        break
    }
    try {
        $sLync = New-PSSession @params -ErrorAction Stop -ErrorVariable LyncSessionError
	    Import-PSSession $sLync
    } catch {
        Write-Warning "Could not connect to Exchange $($LyncSessionError.ErrorRecord)"
    }
} 
#endregion PS Sessions

#region WebRequests
function Invoke-WhoisRequest 
{
    <#
    .Synopsis
       Wohis request.
    .DESCRIPTION
       This function creats a New-WebServiceProxy and then uses the GetWhoIs method to query whois information from www.webservicex.net
    .EXAMPLE
       Invoke-WhoisRequest -DomainName ntsystems.it
       This example queries whois information for the domain ntsystems.it
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [Alias('domain')]
        [string]
        $DomainName
    )
    
    $web = New-WebServiceProxy ‘http://www.webservicex.net/whois.asmx?WSDL’
    $web.GetWhoIs($DomainName)
}

function Get-MacAddressVendor {
    <#
    .Synopsis
       Mac Address vendor lookup.
    .DESCRIPTION
       This function uses Invoke-WebRequest to look up the vendor of a Mac Address' Organizationally Unique Identifier (OUI).
    .EXAMPLE
       Get-MacAddressVendor -MacAddress '00-50-56-C0-00-01','00:0F:FE:E8:4F:27'
       This example looks up the vendor for the two specified Mac Addresses.
    .EXAMPLE
       Get-NetAdapter | Get-MacAddressVendor
       This example looks up the vendor of all network adapters returned by Get-NetAdapter.
    .EXAMPLE
       Get-NetAdapterConfig -ComputerName Server01.domain.local | Get-MacAddressVendor
       This example looks up the vendor of all network adapters returned by Get-NetAdapterConfig which supports remoting.
    .EXAMPLE
       Get-DhcpServerv4Lease -ComputerName DhcpServer -ScopeId 192.168.1.0 | Get-MacAddressVendor
       This example looks up the vendor of all currently assigned address leases on a DHCP Server.
    #>
    [CmdletBinding(PositionalBinding=$true,
                  ConfirmImpact='Medium')]
    Param
    (
        # Specifiy a MAC Address to look up
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("MA")]
        [Alias("ClientId")]
        $MacAddress
    )

    Begin { }
    Process
    {
        foreach ($macAddr in $MacAddress) {
            Write-Verbose "`$macAddr = $macAddr"

            $Request = Invoke-WebRequest -Uri "http://www.macvendorlookup.com/api/BSDvICy/$macAddr"
            Write-Verbose "`$Request = $Request"

            $Data = $Request.Content | ConvertFrom-Csv -Delimiter ',' -Header OUI,Vendor,Street,Address,State,Country
            Write-Verbose "`$Data = $Data"

            $outData = @{
                'MacAddress'=$macAddr -replace ':','' -replace '\.','' -replace '-','';
                'OUI'=$Data.OUI;
                'Vendor'=$Data.Vendor
                'Country'=$Data.Country
            }
            Write-Output (New-Object -TypeName PSObject $outData)
        }
    }
    End { }
}
#endregion WebRequests

#region Converters
function ConvertTo-Base64
{
    <#
    .Synopsis
       Convert a String to Base64
    .DESCRIPTION
       This Function uses [System.Convert] to convert a ClearText String to Base64
    .EXAMPLE
       ConvertTo-Base64 'my cleartext'
    #>
    [CmdletBinding()]
    Param
    (
        # One or more Strings to be converted
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String[]]$String
    )
        Write-Verbose "`$string is $string"
        foreach ($str in $string) {
            Write-Verbose "`$str is $str"
            $objOut = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($str));
            Write-Output $objOut
        }
}

function ConvertFrom-Base64
{
    <#
    .Synopsis
       Convert Base64 to ClearText String
    .DESCRIPTION
       This Function uses [System.Convert] to convert Base64 encoded String to ClearText
    .EXAMPLE
       ConvertFrom-Base64 'YXdlc29tZSwgaXMgaXQ/'
    #>
    [CmdletBinding()]
    Param
    (
        # One or more Strings to be converted
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String[]]$String
    )
        Write-Verbose "`$string is $string"
        foreach ($str in $string) {
            Write-Verbose "`$str is $str"
            $objOut = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($str));
            Write-Output $objOut
        }
}

function ConvertFrom-SID {
    <#
    .Synopsis
       Get the account name for a SID.
    .DESCRIPTION
       Use [System.Security.Principal.SecurityIdentifier].Translate() to get the samAccountName for a SID
    .INPUTS
       You can pipe input to this function.
    .OUTPUTS
       Returns string values.
    .EXAMPLE
       ConvertFrom-SID -Sid S-1-5-21-2330142668-2157844774-769409458
    .EXAMPLE
       "S-1-3-1" | ConvertFrom-SID

    #>
    [CmdletBinding(ConfirmImpact='Medium')]
    Param
    (
        # SID, specify the SID to translate.
        [Parameter(Mandatory=$true,
		   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [System.Security.Principal.SecurityIdentifier]
        $SID
    )

    Process
    {
        $ntAccount = $SID.Translate([System.Security.Principal.NTAccount])
        $ntAccount | Select-Object -ExpandProperty Value
    }
}

function ConvertTo-SID {
    <#
    .Synopsis
       Get the SID for an account name
    .DESCRIPTION
       Use [System.Security.Principal.SecurityIdentifier].Translate() to get the SID for a samAccountName
    .INPUTS
       You can pipe input to this function.
    .OUTPUTS
       Returns string values.
    .EXAMPLE
       ConvertTo-SID -SamAccountName ttorggler
    .EXAMPLE
       "ntsystems\ttorggler" | ConvertTo-SID
    #>
    [CmdletBinding(ConfirmImpact='Medium')]
    Param
    (
        # SamAccountName, specify the account name to translate.
        [Parameter(Mandatory=$true,
		   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [System.Security.Principal.NTAccount]
        $SamAccountName
    )

    Process
    {
        $SID = $SamAccountName.Translate([System.Security.Principal.SecurityIdentifier])
        $SID | Select-Object -ExpandProperty Value
    }
}
#endregion Converters
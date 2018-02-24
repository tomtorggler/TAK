#region Test Connection
function Test-TLSConnection {
    <#
    .Synopsis
       Test if a TLS Connection can be established.
    .DESCRIPTION
       This function uses System.Net.Sockets.Tcpclient and System.Net.Security.SslStream to connect to a ComputerName and
       authenticate via TLS. This is useful to check if a TLS connection can be established and if the certificate used on
       the remote computer is trusted on the local machine.
       If the connection can be established, the certificate's properties will be output as custom object.
       Optionally the certificate can be downloaded using the -SaveCert switch.
       The Protocol parameter can be used to specifiy which SslProtocol is used to perform the test. The CheckCertRevocationStatus parameter
       can be used to disable revocation checks for the remote certificate.
    .EXAMPLE
       Test-TlsConnection -ComputerName www.ntsystems.it
       
       This example connects to www.ntsystems.it on port 443 (default) and outputs the certificate's properties.
    .EXAMPLE
       Test-TlsConnection -ComputerName sipdir.online.lync.com -Port 5061 -Protocol Tls12 -SaveCert

       This example connects to sipdir.online.lync.com on port 5061 using TLS 1.2 and saves the certificate to the temp folder.
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Test-TLSConnection/')]
    [Alias('ttls')]
    [OutputType([psobject],[bool])]
    param (
        # Specifies the DNS name of the computer to test
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("HostName","Server","RemoteHost","Name")]
        $ComputerName,

        # Specifies the TCP port on which the TLS service is running on the computer to test
        [Parameter(Mandatory=$false,
                    Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("RemotePort")]
        [ValidateRange(1,65535)]
        $Port = '443',

        # Specifies a path to a file (.cer) where the certificate should be saved if the SaveCert switch parameter is used
        [Parameter(Mandatory=$false,
                    Position=2)]
        [System.IO.FileInfo]
        $FilePath = "$env:TEMP\$computername.cer",

        [Parameter(Mandatory=$false,
                    Position=2)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Default','Ssl2','Ssl3','Tls','Tls11','Tls12')]
        [System.Security.Authentication.SslProtocols[]]
        $Protocol = 'Default',

        # Check revocation information for remote certificate. Default is true.
        [Parameter(Mandatory=$false)]
        [bool]$CheckCertRevocationStatus = $true,

        # Saves the remote certificate to a file, the path can be specified using the FilePath parameter
        [switch]
        $SaveCert,

        # Only returns true or false, instead of a custom object with some information.
        [switch]
        $Silent
    )

    begin { }

    process {

        if($PSVersionTable.PSEdition -eq "Core") {
            Write-Verbose "PSEdition is $($PSVersionTable.PSEdition)"
    
            if (Test-Path (which openssl)) {
                Write-Verbose "Found openssl at $(which openssl)"
    
                Start-Process -FilePath openssl -ArgumentList "s_client -connect $(-join ($ComputerName,":",$Port))" -RedirectStandardOutput /Users/ttor/tmpcert123
                $certificate = Get-Content -Path /Users/ttor/tmpcert123
                $certificateX509 = New-Object system.security.cryptography.x509certificates.x509certificate2($certificate)
                $certificateX509
    
            } else {
                Write-Warning "Could not find openssl."
            }
    
        } else {
            Write-Verbose "PSEdtion is $($PSVersionTable.PSEdition)"
    
            try {
                $TCPConnection = New-Object System.Net.Sockets.Tcpclient($ComputerName, $Port)
                Write-Verbose "TCP connection has succeeded"
                $TCPStream     = $TCPConnection.GetStream()
                try {
                    $SSLStream = New-Object System.Net.Security.SslStream($TCPStream)
                    Write-Verbose "SSL connection has succeeded with $($SSLStream.SslProtocol)"
                    try {
                        # AuthenticateAsClient (string targetHost, X509CertificateCollection clientCertificates, SslProtocols enabledSslProtocols, bool checkCertificateRevocation)
                        $SSLStream.AuthenticateAsClient($ComputerName,$null,$Protocol,$CheckCertRevocationStatus)
                        Write-Verbose "SSL authentication has succeeded"
                    } catch {
                        Write-Warning "There's a problem with SSL authentication to $ComputerName `n$_"
                        return $false
                    }
                    $certificate = $SSLStream.get_remotecertificate()
                    $certificateX509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
                    $SANextensions = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection($certificateX509)
                    $SANextensions = $SANextensions.Extensions | Where-Object {$_.Oid.FriendlyName -eq "subject alternative name"}
    
                    $data = [ordered]@{
                        'ComputerName' = $ComputerName;
                        'Port' = $Port;
                        'Protocol' = $SSLStream.SslProtocol;
                        'CheckRevocation' = $SSLStream.CheckCertRevocationStatus;
                        'Issuer' = $SSLStream.RemoteCertificate.Issuer;
                        'Subject' = $SSLStream.RemoteCertificate.Subject;
                        'SerialNumber' = $SSLStream.RemoteCertificate.GetSerialNumberString();
                        'ValidTo' = $SSLStream.RemoteCertificate.GetExpirationDateString();
                        'SAN' = $SANextensions.Format(1);
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
                $exception = New-Object System.Net.Sockets.SocketException
                $errorcode = $exception.ErrorCode
                Write-Warning "TCP connection to $ComputerName with IP $(([net.dns]::GetHostByName($ComputerName)).addresslist.ipaddresstostring) failed, error code:$errorcode"
                Write-Warning "Error details: $exception"
            }
        }
    } # process

    end {
        # cleanup
        Write-Verbose "Cleanup sessions"
        $SSLStream.Dispose()
        $TCPStream.Dispose()
        $TCPConnection.Dispose()
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
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/test-tcpconnection/')]
    [Alias('ttcp')]
    [OutputType([bool])]
    param (
        # Specifies the DNS name of the computer to test
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("HostName","Server","RemoteHost")]
        $ComputerName,

        # Specifies the TCP port to test on the remote computer.
        [Parameter(Mandatory=$false,
                    Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("RemotePort")]
        [ValidateRange(1,65535)]
        $Port = '80',

        # Specifies the number of tests to run, this can be useful when testing load-balanced services; default is 1
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
        # output the connected state of TCPConnection
        $TCPConnection.Connected
        $TCPConnection.Dispose()
    }
}
#endregion Test Connection

#region Test Skype for Business / Lync deployment
function Test-SfBDNS {
    <#
    .Synopsis
       Test DNS entries for Skype for Business / Lync deployments.
    .DESCRIPTION
       This function uses Resolve-DnsName to query well-known DNS records for Skype for Business / Lync deployments.
       The NameSever parameter can be used to specify a nameserver.
    .EXAMPLE
       Test-LyncDNS -SipDomain uclab.eu
       This example queries DNS records for the domain uclab.eu
    #>

    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Test-SfBDNS/')]

    param(
        # Specifies the DNS domain name to test
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        $SipDomain,

        # Specifies the nameserver which is used by Resolve-DnsName
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [Alias("Server")]
        [ipaddress]
        $NameServer,

        # A quick way to use OpenDns servers instead of using NameServer
        [switch]
        $OpenDNS,

        # Do also query for internal records, they should only resolve when testing from the internal network
        [switch]
        $internal,

        # Do also test a TLS connection to the servers received from the query
        [switch]
        $testConnection
    )

    if ($MyInvocation.InvocationName -ne $MyInvocation.MyCommand) {
        Write-Host "Please use $($MyInvocation.MyCommand), this alias will be deprecated in a future version." -ForegroundColor Yellow
    }

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

function Test-SfBDiscover {
    <#
    .Synopsis
       Test the Lyncdiscover service for Skype for Business/Lync deployments
    .DESCRIPTION
       This function uses Invoke-RestMethod to test if the Lyncdiscover service is responding for a given domain.
    .EXAMPLE
       Test-LyncDiscover -SipDomain uclab.eu -Http
       This example gets Lyncdiscover information over http for the domain uclab.eu
    #>

    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Test-SfBDiscover/')]
    param(
        # Specifies a DNS domain name to test
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        $SipDomain,

        # Use HTTP instead of HTTPS
        [switch]
        $Http,

        # Use internal name (lyncdiscoverinternl) instead of the external one (lyncdiscover)
        [switch]
        $internal,

        # Test against Office 365 endpoints
        [switch]
        $Online

    )

    if ($MyInvocation.InvocationName -ne $MyInvocation.MyCommand) {
        Write-Host "Please use $($MyInvocation.MyCommand), this alias will be deprecated in a future version." -ForegroundColor Yellow
    }

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

    if($Online) {
        $uri = "https://webdir.online.lync.com/Autodiscover/AutodiscoverService.svc/root?originalDomain=$SipDomain"
    }

    try {
        $webRequest = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        Write-Verbose $webRequest
    } catch {
        Write-Warning "Could not connect to $uri error $_"
        return
    }
    $out = [ordered]@{
        "self" = $webRequest._links.self.href
        "user" = $webRequest._links.user.href
        "xframe" = $webRequest._links.xframe.href
    }
    # Create a custom object and add a custom TypeName for formatting before writing to pipeline
    Write-Output (New-Object -TypeName psobject -Property $out | Add-Member -TypeName 'System.TAK.SFBDiscover' -PassThru) 
}

#endregion Test Lync deployment

#region EtcHosts
function Show-EtcHosts {
    <#
    .Synopsis
       Display /etc/hosts file content on Windows or Linux/macOS.
    .DESCRIPTION
       This funtion gets the content of the hosts file, parses the lines and outputs
       a custom object with HostName and IPAddress properties.
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Show-EtcHosts/')]
    param()
    # Alias/OutputType don't seem to work on Core?
    #[Alias('shosts')]
    #[OutputType([psobject])]

    if($PSVersionTable.PSEdition -eq "Core") {
        Write-Verbose "PSEdition is $($PSVersionTable.PSEdition)"
        $hostsPath = "/etc/hosts"
    } else {
        Write-Verbose "PSEdtion is $($PSVersionTable.PSEdition)"
        $hostsPath = Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts
    }

    # get all lines that don't start with #
    $lines = Select-String -Path $hostsPath -Pattern "^[^#]" |Select-Object -ExpandProperty line

    if ($lines){
        # Split the content of $lines
        $linesSplit = $lines -split '\s+'

        # looping through the array, create key:value pairs and add them to $outData
        for ($i = 0; $i -lt $linesSplit.Count; $i++) {
            if ([bool]!($i%2)) {
                $j = $i + 1
                $outData = @{'IPAddress'=$linesSplit[$i];'HostName'=$linesSplit[$j]}

                # create custom object and write it to the pipeline
                Write-Output (New-Object -TypeName psobject -Property $outData)
            }
        }
    }
}

function Edit-EtcHosts {
    <#
    .Synopsis
       Edit \etc\hosts file with notepad.
    .DESCRIPTION
       This funtion starts notepad.exe as administrator and opens the hosts file for editing.
       If this function is running on PowerShell Core, it runs "sudo vi /etc/hosts"
    #>
    # run notepad as administrator and open the hosts file for editing
    if($PSVersionTable.PSEdition -eq "Core") {
        Write-Verbose "PSEdition is $($PSVersionTable.PSEdition)"
        $hostsPath = "/etc/hosts"
        # would be nice to use $EDITOR varialbe...
        sudo vi $hostsPath
    } else {
        Write-Verbose "PSEdtion is $($PSVersionTable.PSEdition)"
        $hostsPath = Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts
        Start-Process notepad -Verb RunAs -ArgumentList $hostsPath
    }
}

function Add-EtcHostsEntry {
    <#
    .Synopsis
       Add an entry to local hosts file.
    .DESCRIPTION
       Adds a lines to the /etc/hosts file of the local computer.
       Requires write access to /etc/hosts - if running PowerShell Core on  Linux/macOS try "sudo powershell"
    .EXAMPLE
       Add-EtcHostsEntry -IPAddress 1.1.1.1 -Fqdn test.fqdn

       This example adds following line to the hosts file
       1.1.1.1 test.test
    #>

    [CmdletBinding(
        HelpUri = 'https://ntsystems.it/PowerShell/TAK/add-etchostsentry/',
        SupportsShouldProcess=$true,
        ConfirmImpact='Medium')]
    Param
    (
        # IPAddress of the hosts entry to be added
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("ip")]
        [String]
        $IPAddress,

        # FQDN of the hosts entry to be added
        [Parameter(Mandatory=$true,
                   Position=1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Fqdn
    )

    if($PSVersionTable.PSEdition -eq "Core") {
        Write-Verbose "PSEdition is $($PSVersionTable.PSEdition)"
        $hostsPath = "/etc/hosts"
    } else {
        Write-Verbose "PSEdtion is $($PSVersionTable.PSEdition)"
        $hostsPath = Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts
    }

    $line = $IPAddress,$Fqdn -join "`t"

    if ($pscmdlet.ShouldProcess("$hostsPath", "Add $line")) {
        try {
            Add-Content -Path $hostsPath -Value ("`r`n"+$line) -NoNewline -ErrorAction Stop
        } catch {
            Write-Warning "Could not add entry: $_"
        }
    }
} # End Add-EtcHostsEntry

function Remove-EtcHostsEntry {
    <#
    .Synopsis
       Remove an entry from local hosts file by it's IP address.
    .DESCRIPTION
       Find an IP address and remove all lines where it appears from the \etc\hosts file of the local computer.
    .EXAMPLE
       Remove-EtcHostsEntry -IPAddress 1.1.1.1

       This example removes following lines from the hosts file
       1.1.1.1 test.test
       1.1.1.1 another.test.com
    #>

    [CmdletBinding(SupportsShouldProcess=$true,
                  ConfirmImpact='Medium')]
    Param
    (
        # IPAddress of the hosts entry to be added
        [Parameter(Mandatory=$false,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("ip")]
        [String]
        $IPAddress
    )
        $hostsPath = Join-Path -Path $env:SystemRoot -ChildPath System32\drivers\etc\hosts
        $NewContent = Select-String -Path $hostsPath -Pattern "^(?!$IPAddress)" | Select-Object -ExpandProperty line

    if ($pscmdlet.ShouldProcess("$hostsPath", "Remove $IPAddress")) {
        try {
            Set-Content -Value $NewContent -Path $hostsPath -ErrorAction Stop
        } catch {
            Write-Warning "Could not remove entry: $_"
        }
    }

} # End Add-EtcHostsEntry


#endregion EtcHosts

#region PS Sessions
function Connect-Exchange
{
    [CmdletBinding()]
    Param
    (
        # Specifies the ServerName that the session will be connected to
        [Parameter(Mandatory=$true,
                   ParameterSetName="Server",
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Server,

        # Credential used for connection; if not specified, the currently logged on user will be used
        [pscredential]
        $Credential,

        # Specify the Online switch to connect to Exchange Online / Office 365
        [Parameter(ParameterSetName="Online")]
        [switch]
        $Online
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
    if ($Online) {
        if (-not($params.Credential)) {
            $params.Credential = Get-Credential
        }
        $params.ConnectionUri = "https://outlook.office365.com/powershell-liveid/"
        $params.Authentication = "Basic"
        $params.Add("AllowRedirection",$true)
    }
    try {
        Write-Verbose "Trying to connect to $($params.ConnectionUri)"
        $sExch = New-PSSession @params -ErrorAction Stop -ErrorVariable ExchangeSessionError
	    Import-Module (Import-PSSession $sExch -AllowClobber) -Global
    } catch {
        Write-Warning "Could not connect to Exchange $($ExchangeSessionError.ErrorRecord)"
    }
}

function Connect-SfB
{
    [CmdletBinding()]
    Param
    (
        # Specifies the ServerName that the session will be connected to
        [Parameter(Mandatory=$true,
                   ParameterSetName = "Server",
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Server,

        # Specify the Online switch to connect to SfB Online using the SkypeOnlineConnector module
        [Parameter(ParameterSetName="Online")]
        [switch]
        $Online,

        # Specify the admin doamin to connect to (OverrideAdminDomain parameter)
        [Parameter(ParameterSetName="Online")]
        [string]
        $AdminDomain,

        # Credential used for connection; if not specified, the currently logged on user will be used
        [Parameter(Position=0,
            ParameterSetName="Server")]
        [pscredential]
        $Credential
    )
    if ($MyInvocation.InvocationName -ne $MyInvocation.MyCommand) {
        Write-Host "Please use $($MyInvocation.MyCommand), this alias will be deprecated in a future version." -ForegroundColor Yellow
    }
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
        if($Online -and (Get-Command -Name New-CsOnlineSession -ErrorAction SilentlyContinue)) {

            if($AdminDomain -notmatch ".onmicrosoft.com") {
                $AdminDomain = -join($AdminDomain,".onmicrosoft.com")
            }

            Write-Verbose "Using New-CsOnlineSession"
            $sLync = New-CsOnlineSession -OverrideAdminDomain $AdminDomain -ErrorAction Stop -ErrorVariable LyncSessionError        
        } else {
            Write-Verbose "Trying to connect to ($$params.ConnectionUri)"
            $sLync = New-PSSession @params -ErrorAction Stop -ErrorVariable LyncSessionError
        } 
        Import-Module (Import-PSSession $sLync -AllowClobber) -Global
    }
    catch {
        Write-Warning "Could not connect to Exchange $($LyncSessionError.ErrorRecord)"
    }
}
#endregion PS Sessions

#region WebRequests
function Get-MacAddressVendor {
    <#
    .Synopsis
       Mac Address vendor lookup.
    .DESCRIPTION
       This function uses Invoke-WebRequest to look up the vendor of a Mac Address' Organizationally Unique Identifier (OUI).
       Works on PowerShell Core for Linux/macOS.
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
    [CmdletBinding(
        HelpUri = 'https://ntsystems.it/PowerShell/TAK/get-macaddressvendor/',
        PositionalBinding=$true)]
    [OutputType([psobject])]
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
    [CmdletBinding()]
    [Alias('whois')]
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
       Beleive it or not, works on Linux/macOS!
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
       This Function uses [System.Convert] to convert Base64 encoded String to ClearText.
       Beleive it or not, works on Linux/macOS!
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
        [ValidatePattern("S-1-5-\d{2}-\d+")]
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

#region Tools

function Update-FileWriteTime {
    <#
    .Synopsis
       Touch a file.
    .DESCRIPTION
       This function checks whether a given file exists, and if so, updates the LastWriteTime property of the given file.
       Should the file not exist, a new, empty file is created. This function works on Linux/macOS.
    .EXAMPLE
       touch myfile

       This example creates myfile if it does not exist in the current directory.
       If the file does exist, the LastWriteTime property will be updated.
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/update-filewritetime/')]
    [Alias('touch')]
    Param
    (
        # One or more filenames to be touched
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String[]]$Name,
        # Specify a specific date for LastWriteTime
        [datetime]$Date = (Get-Date)
    )
    process {
        foreach($file in $Name) {
            $item = Get-Item -Path $file -ErrorAction SilentlyContinue
            if($item) {
                Write-Verbose "File does exist, updating LastWriteTime"
                Set-ItemProperty -Path $file -Name LastWriteTime -Value $Date
            } else {
                Write-Verbose "File does not exist, creating file"
                New-Item -Path $file -ErrorAction Stop
            }
        }
    }
}

function Get-Hash {
    <#
    .Synopsis
       Get hash for a string.
    .DESCRIPTION
       This function uses various various crypto service providers to get the hash value for a given input string.
    .EXAMPLE
       Get-Hash "Hello World!"

       This example returns the MD5 hash of "Hello World!".
    .EXAMPLE
       Get-Hash "Hello World!" -Algorithm Sha256

       This example gets the SHA256 hash of "Hello World!".
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/get-hash/')]
    param (
        [Parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$True)]
        [string]
        $String,
        [Parameter(Mandatory=$false,
            Position=1)]
        [ValidateSet('MD5','SHA1','SHA256','SHA512')]
        $Algorithm
    )
    # define Variable for crypto provider and string builder
    switch ($Algorithm) {
        "SHA1"{$cryptoProvider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider}
        "SHA256"{$cryptoProvider = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider}
        "SHA512"{$cryptoProvider = New-Object System.Security.Cryptography.SHA512CryptoServiceProvider}
        Default{$cryptoProvider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider}
    }
    $stringBuilder = New-Object System.Text.StringBuilder
    foreach ($byte in $cryptoProvider.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))){
        $null = $stringBuilder.Append($byte.ToString("X2")) 
    }        
    Write-Output ($stringBuilder.ToString().ToLower())
}
function Show-WlanProfile {
    <#
    .Synopsis
       Get wlan pre-shared key.
    .DESCRIPTION
       This function invokes the netsh tool to get the pre-shared key for a given wireless lan profile.
    .EXAMPLE
       Show-WlanProfile "my_net"

       This example shows the key for the wlan profile "my_net"
    .EXAMPLE
       Get-WlanProfile | Show-WlanProfile

       This example shows the keys for all known wlan profiles on the system.
    #>
    [cmdletbinding()]
    param(
        [Parameter(
            ValueFromPipeline=$true
        )]
        $Name
    )
    process {
        $x = Invoke-Expression "netsh wlan show profile $name key=clear" 
        $x | Select-String -Pattern "SSID Name|Key Content"
    }
}

function Get-WlanProfile {
    # quick hack to get all known wlan profiles
    $x = Invoke-Expression "netsh wlan show profile"
    $x = $x | Select-String -Pattern "All User Pr"
    $y = $x -replace("All User Profile     :","Name=") | ConvertFrom-StringData
    $y | Select-Object -ExpandProperty Values
}

#endregion Tools

#region define aliases 

New-Alias -Name Test-LyncDiscover -Value Test-SfBDiscover -ErrorAction SilentlyContinue
New-Alias -Name Test-LyncDNS -Value Test-SfBDNS -ErrorAction SilentlyContinue
New-Alias -Name Connect-Lync -Value Connect-SfB -ErrorAction SilentlyContinue

#endregion aliases
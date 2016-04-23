
function Test-TLSConnection  {
    [CmdletBinding(SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.ntsystems.it/')]
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

        [Parameter(Mandatory=$false)]
        [switch]
        $SaveCert,

        [switch]
        $Silent,
        
        [Parameter(Mandatory=$false, 
                    Position=2)]
        [System.IO.FileInfo]
        $FilePath = "$env:TEMP\$computername.cer"
            
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
                return $true
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

} # end function test-tlsconnection


function Test-TCPConnection  {
    [CmdletBinding(SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.ntsystems.it/')]
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
        } Catch {}

        If ($?) {
            Write-Output $True
            $TCPConnection.Close()
        } else {
            Write-Output $false
        }
        $TCPConnection.Dispose()
    }
    
} # end function Test-TCPConnection


function Show-EtcHosts {
    # filter out comments and empty lines
    $lines = Get-Content C:\Windows\System32\drivers\etc\hosts | Where-Object {$PSItem -notmatch "^#" -and $PSItem -ne ""}
        if ($lines){        # Split the content of $lines        $linesSplit = $lines -split '\s+'            
        # looping through the array, create key:value pairs and add them to $outData
        for ($i = 0; $i -lt $linesSplit.Count; $i++) {
            if ([bool]!($i%2)) {
                $j = $i + 1 
                $outData = @{'IPAddress'=$linesSplit[$i];'Hostname'=$linesSplit[$j]}
                                # create custom object and write it to the pipeline                Write-Output (New-Object -TypeName psobject -Property $outData)
            }
        }    }
}
function Edit-EtcHosts {
    Start-Process notepad -Verb RunAs -ArgumentList C:\Windows\System32\drivers\etc\hosts
}

#region Connect-Exchange
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
        Write-Host "Already connected to Exchange"
        break
    }
    try {
        $sExch = New-PSSession @params -ErrorAction Stop -ErrorVariable ExchangeSessionError
	    Import-PSSession $sExch
    } catch {
        Write-Warning "Could not connect to Exchange $($ExchangeSessionError.ErrorRecord)"
    }
} # end Connect-Exchange

# quick funtion to connect to lync
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
        Write-Host "Already connected to Lync"
        break
    }
    try {
        $sLync = New-PSSession @params -ErrorAction Stop -ErrorVariable LyncSessionError
	    Import-PSSession $sLync
    } catch {
        Write-Warning "Could not connect to Exchange $($LyncSessionError.ErrorRecord)"
    }
} 
#endregion Connect-Exchange

#region Invoke-WohisRequest
function Invoke-WhoisRequest 
{
    <#
    .Synopsis
       Wohis request.
    .DESCRIPTION
       This function creats a New-WebServiceProxy and then uses the GetWhoIs method to query whois information from www.webservicex.net
    .EXAMPLE
       Invoke-WhoisRequest -Domain ntsystems.it
       This example queries whois information for the domain ntsystems.it
    #>
    [cmdletbinding()]
    param($Domain)
    
    $web = New-WebServiceProxy ‘http://www.webservicex.net/whois.asmx?WSDL’
    $web.GetWhoIs($domain)
}
#endregion Invoke-WohisRequest

#region Get-MacAddressVendor
function Get-MacAddressVendor
{
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

    Begin
    {
    }
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
    End
    {
    }
}
#endregion Get-MacAddressVendor


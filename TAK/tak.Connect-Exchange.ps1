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
        [Parameter()]
        [pscredential]
        $Credential,

        # Specify the Online switch to connect to Exchange Online / Office 365
        [Parameter(ParameterSetName="Online")]
        [switch]
        $Online,
        
        # Specify the Protection switch to connect to Exchange Online / Office 365 Security and Compliance
        [Parameter(ParameterSetName="Protection")]
        [switch]
        $Protection,

        # ProxyAccessType to use for the PsSession
        [Parameter()]
        [System.Management.Automation.Remoting.ProxyAccessType]
        $ProxyType = "None"
    )
    $ExistingSessions = Get-PSSession
    if ($ExistingSessions.ConfigurationName -ne "Microsoft.Exchange" -and $Credential) {
        $params = @{
            ConfigurationName = "Microsoft.Exchange";
            Name = "ExchMgmt";
            Authentication = "Kerberos";
            Credential = $Credential;
            ConnectionUri = "http://$Server/PowerShell/"
        }
    } elseif ($ExistingSessions.ConfigurationName -ne "Microsoft.Exchange" -and (-not $Credential)) {
        $params = @{
            ConfigurationName = "Microsoft.Exchange";
            Name = "ExOnPrem";
            Authentication = "Kerberos";
            ConnectionUri = "http://$Server/PowerShell/"
        }
    } elseif ($ExistingSessions.ConfigurationName -eq "Microsoft.Exchange" -and $ExistingSessions.State -eq "Opened") {
        Write-Verbose "Already connected to Exchange"
    #   break
    }
    $ExchOption = New-PSSessionOption -ProxyAccessType $ProxyType
    try {
        if($Protection -and (Get-Command -Name New-ExoPSSession -ErrorAction SilentlyContinue)) {
            Write-Verbose "Connecting using Modern Auth"
            $sExch = New-ExoPSSession -PSSessionOption $ExchOption -ErrorAction Stop -ErrorVariable ExchangeSessionError -ConnectionURI "https://ps.compliance.protection.outlook.com/PowerShell-LiveId" -AzureADAuthorizationEndpointUri "https://login.windows.net/common"
        } elseif ($online -and (Get-Command -Name New-ExoPSSession -ErrorAction SilentlyContinue)) {
            Write-Verbose "Connecting using Modern Auth"
            $sExch = New-ExoPSSession -PSSessionOption $ExchOption -ErrorAction Stop -ErrorVariable ExchangeSessionError
        } elseif ($Online) {
            if (-not($params.Credential)) {
                $params.Credential = Get-Credential
            }
            $params.ConnectionUri = "https://outlook.office365.com/powershell-liveid/"
            $params.Authentication = "Basic"
            $params.Name = "ExOnline"
            $params.Add("AllowRedirection",$true)
        } else {
            Write-Verbose "Trying to connect to $($params.ConnectionUri)"
            $sExch = New-PSSession @params -SessionOption $ExchOption -ErrorAction Stop -ErrorVariable ExchangeSessionError
        }
        Import-Module (Import-PSSession $sExch -AllowClobber) -Global -WarningAction SilentlyContinue
    } catch {
        Write-Warning "Could not connect to Exchange $($ExchangeSessionError.ErrorRecord)"
    }
}

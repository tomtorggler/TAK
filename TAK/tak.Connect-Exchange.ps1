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
        $Online,

        # ProxyAccessType to use for the PsSession
        [Parameter()]
        [System.Management.Automation.Remoting.ProxyAccessType]
        $ProxyType = "None"
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
            Name = "ExOnPrem";
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
        $params.Name = "ExOnline"
        $params.Add("AllowRedirection",$true)
    }
    $ExchOption = New-PSSessionOption -ProxyAccessType $ProxyType
    try {
        Write-Verbose "Trying to connect to $($params.ConnectionUri)"
        $sExch = New-PSSession @params -SessionOption $ExchOption -ErrorAction Stop -ErrorVariable ExchangeSessionError
        Import-Module (Import-PSSession $sExch -AllowClobber) -Global
    } catch {
        Write-Warning "Could not connect to Exchange $($ExchangeSessionError.ErrorRecord)"
    }
}
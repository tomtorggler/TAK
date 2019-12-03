function Connect-SfB {
    <#
    .SYNOPSIS
        Connect to Skype for Business Server or Online.
    .DESCRIPTION
        This function uses New-PSSession or New-CsOnlineSession to connect to Skype for Business (or Lync) Servers
        or Skype for Business Online. The resulting PS Session is then imported and makes cmdlets available in the current session.
        The Timeout and ProxyType parameters are used to configure the PSSessionOption with respective values.
    .EXAMPLE
        PS C:\> Connect-SfB -Online -AdminDomain uclab
        This example connects to Skype for Business Online setting the OverrideAdminDomain to uclab.onmicrosoft.com
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES 
        Author: @torggler
    #>
    [CmdletBinding()]
    Param
    (
        # Specifies the ServerName that the session will be connected to
        [Parameter(Mandatory=$true,
                   ParameterSetName = "Server",
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Server,

        # Specify the admin doamin to connect to (OverrideAdminDomain parameter)
        [Parameter(ParameterSetName="Online")]
        [string]
        $AdminDomain,

        # Credential used for connection; if not specified, the currently logged on user will be used
        [Parameter(Position=0,
            ParameterSetName="Server")]
        [pscredential]
        $Credential,

        # Session idle timeout in seconds
        [Parameter()]
        [ValidateRange(60,21474836)]
        [int]
        $Timeout = 3600,

        # ProxyAccessType to use for the PsSession
        [Parameter()]
        [System.Management.Automation.Remoting.ProxyAccessType]
        $ProxyType = "None"
    )
    if ($MyInvocation.InvocationName -ne $MyInvocation.MyCommand) {
        Write-Host "Please use $($MyInvocation.MyCommand), this alias will be deprecated in a future version." -ForegroundColor Yellow
    }
    if ((Get-PSSession).Name -ne "LyncMgmt" -and $Credential) {
        $params = @{
            Name = "LyncMgmt";
            Authentication = "Negotiate";
            Credential = $Credential;
            ConnectionUri = "https://$Server/ocsPowerShell/"
        }
    } elseif ((Get-PSSession).Name -ne "LyncMgmt" -and (-not $Credential)) {
        $params = @{
            Name = "LyncMgmt";
            Authentication = "Negotiate";
            ConnectionUri = "https://$Server/ocsPowerShell/"
        }
    } else {
        Write-Warning "Already connected to Lync"
        break
    }
    $LyncOption = New-PSSessionOption -IdleTimeout (New-TimeSpan -Seconds $Timeout).TotalMilliseconds -ProxyAccessType $ProxyType
    try {
        if($AdminDomain -and (Get-Command -Name New-CsOnlineSession -ErrorAction SilentlyContinue)) {
            if($AdminDomain -notmatch ".onmicrosoft.com") {
                $AdminDomain = -join($AdminDomain,".onmicrosoft.com")
            }
            Write-Verbose "Using New-CsOnlineSession with Idle timeout: $($LyncOption.IdleTimeout) and ProxyType:  $($LyncOption.ProxyAccessType)"
            $sLync = New-CsOnlineSession -OverrideAdminDomain $AdminDomain -SessionOption $LyncOption -ErrorAction Stop -ErrorVariable LyncSessionError   
        } else {
            Write-Verbose "Trying to connect to $($params.ConnectionUri) with Idle timeout: $($LyncOption.IdleTimeout) and ProxyType:  $($LyncOption.ProxyAccessType)"
            $sLync = New-PSSession @params -SessionOption $LyncOption -ErrorAction Stop -ErrorVariable LyncSessionError
        } 
        Import-Module (Import-PSSession $sLync -AllowClobber) -Global -WarningAction SilentlyContinue
    }
    catch {
        Write-Warning "Could not connect to Skype for Business $($LyncSessionError.ErrorRecord)"
    }
}
function Test-OOSFarm {
    <#
    .SYNOPSIS
        Get internal and external URLs for PowerPoint sharing.
    .DESCRIPTION
        This function uses Invoke-RestMethod to get and parse hosting discovery information for Office Online Server farms.
        If successfull, it returns a custom object with the internal and external URL for PowerPoint sharing.
    .EXAMPLE
        PS C:\> Test-OOSFarm -Name oos.example.com
        This example tries to retrieve information from https://oos.example.com/hosting/discovery
    .INPUTS
        <none>
    .OUTPUTS
        [psobject]
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param(
        # Specifies the name of the OOS server/farm 
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        [Alias("Server","Farm","Name")]
        $ComputerName
    )
    $uri = "https://$ComputerName/hosting/discovery"
    try {
        $r = Invoke-RestMethod -Uri $uri -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not connect to $ComputerName"
    }
    if ($r) {
        New-Object -TypeName psobject -Property ([ordered]@{
            InternalURL = [system.uri]$r.'wopi-discovery'.'net-zone'.where{ $_.name -eq "internal-https" }.app.where{ $_.name -eq "PowerPoint" }.action.where{ $_.name -eq "presentservice" -and $_.ext -eq "pptx" }.urlsrc
            ExternalURL = [system.uri]$r.'wopi-discovery'.'net-zone'.where{ $_.name -eq "external-https" }.app.where{ $_.name -eq "PowerPoint" }.action.where{ $_.name -eq "presentservice" -and $_.ext -eq "pptx" }.urlsrc
            InternalBootstrapper = ([system.uri]@($r.'wopi-discovery'.'net-zone'.where{ $_.name -eq "internal-https" }.app.where{$_.bootstrapperUrl}.bootstrapperUrl)[0]).DnsSafeHost
            ExternalBootstrapper = ([system.uri]@($r.'wopi-discovery'.'net-zone'.where{ $_.name -eq "external-https" }.app.where{$_.bootstrapperUrl}.bootstrapperUrl)[0]).DnsSafeHost
        })
    }
}

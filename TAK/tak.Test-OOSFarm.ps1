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
    param($Name)
    $uri = "https://$name/hosting/discovery"
    try{
        $r = Invoke-RestMethod -Uri $uri -ErrorAction Stop
    } catch {
        Write-Warning "Could not connect to $Name"
    }
    if ($r) {
        New-Object -TypeName psobject -Property @{
            Internal = $r.'wopi-discovery'.'net-zone'.where{$_.name -eq "internal-https"}.app.where{$_.name -eq "PowerPoint"}.action.where{$_.name -eq "presentservice" -and $_.ext -eq "pptx"}.urlsrc
            External = $r.'wopi-discovery'.'net-zone'.where{$_.name -eq "external-https"}.app.where{$_.name -eq "PowerPoint"}.action.where{$_.name -eq "presentservice" -and $_.ext -eq "pptx"}.urlsrc           
        }
    }
}



function New-DKIMRecord {
    <#
    .SYNOPSIS
        Create DNS records for DKIM.
    .DESCRIPTION
        This function uses `Get-DkimSigningConfig` to create a list of records that can be sent to a DNS admin.
        This function requires a connection to Exchange Online PowerShell.
    .EXAMPLE
        PS C:\> Connect-ExchangeOnline
        PS C:\> New-DKIMRecord | Export-Csv -NoType -Path dkimrecords.csv

        This example connects to Exchange Online and creates the DNS records. When run without parameter, the function writes custom objects to the pipeline. 
        The output can be redirected to other cmdlets 
    .EXAMPLE
        PS C:\> New-DKIMRecord -PrintResult

        This example assumes you are already connected to Exchange Online. The function creates the DNS records and prints them in an easily readable format when the `PrintResult` switch parameter is used.
    .INPUTS
        None.
    .OUTPUTS
        [PSCustomObject]
    .NOTES
        Author: @torggler
    #>
    [CmdletBinding(HelpUri = 'https://onprem.wtf/PowerShell/TAK/New-DKIMRecord/')]
    param (
        [string]
        $Domain,
        [string]
        $Exclude = "onmicrosoft",
        [switch]
        $PrintResult
    )
    
    if(-not (Get-Command Get-DkimSigningConfig)) {
        Write-Warning "Connect to Exchange Online PowerShell with: Connect-ExchangeOnline"
    } else {
        if($Domain){
            $DkimSigningConfig = Get-DkimSigningConfig -Identity $Domain
        } else {
            $DkimSigningConfig = Get-DkimSigningConfig | Where-Object -Property Identity -NotMatch $Exclude
        }
        foreach($dkim in $DkimSigningConfig){
            $out = [PSCustomObject]@{
                Domain = $dkim.name
                Selector1 = ($dkim.Selector1CNAME -split "-" | Select-Object -First 1),"_domainkey" -join "."
                Selector1CNAME = $dkim.Selector1CNAME
                Selector2 = ($dkim.Selector2CNAME -split "-" | Select-Object -First 1),"_domainkey" -join "."
                Selector2CNAME = $dkim.Selector2CNAME
            }
            if($PrintResult){
                $OutStringS1 = "{0}.{1} -> {2}" -f $out.selector1,$out.Domain,$out.Selector1CNAME
                $OutStringS2 = "{0}.{1} -> {2}" -f $out.selector2,$out.Domain,$out.Selector2CNAME
                Write-Information $OutStringS1 -InformationAction Continue
                Write-Information $OutStringS2 -InformationAction Continue
            } else {
                Write-Output $out
            }
        }
    }
}

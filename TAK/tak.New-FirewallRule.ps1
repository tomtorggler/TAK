function New-FirewallRule {
    <#
    .SYNOPSIS
        Create a new Windows Firewall Rule.
    .DESCRIPTION
        This function is wrapper for New-NetFirewallRule with the goal of making it easier to create simple firewall rules and have consistent naming. 
    .EXAMPLE
        PS C:\> New-FirewallRule -Port 6060
        This example creats a new firewall rule to allow connections on tcp/6060.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES
        Author: @torggler
    #>
    [CmdletBinding()]
    Param(
        [ValidateRange(1,65535)]
        [int]$Port,
        [ValidateSet("UDP","TCP")]
        [string]$Protocol = "TCP",
        [ValidateSet("PersistentStore","ActiveStore")]
        [string]$Store = "PersistentStore"
    )
    $params = @{
        DisplayName = "Allow $Protocol/$port in $Store";
        Action = 'Allow';
        Description = "Allow $Protocol/$port in $Store";
        Enabled = 1;
        Profile = 'Any';
        Protocol = $Protocol;
        PolicyStore = $Store;
        LocalPort=$Port;
        ErrorAction = 'Stop';
    }
    try {
        Write-Verbose "Creating new Rule: Allow $Protocol/$port in $Store" 
        $null = New-NetFirewallRule @params
    }
    catch {
        Write-Warning "Could not create firewall rule: $_"
    }
}

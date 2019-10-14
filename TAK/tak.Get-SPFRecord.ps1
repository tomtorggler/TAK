class SPFRecord {
    [String] $tag
    [string] $value
    SPFRecord([String] $tag, [string]$value) {
        $this.tag = $tag
        $this.value = $value
    }
}
function Get-IncludedSpf($string) {
    # this gets just the first include tag
    # [regex]::match($string,"include:(\S+)").groups[1].value
    # so instead we are creating temporary objects for all tags to then filter out all includes
    $splitString = $string -split " " | Where-Object {$_ -match ":"}
    $splitString = $splitString -split ":"
    for ($i = 0; $i -lt $splitString.Count; $i++) {
        if ([bool]!($i%2)) {
            [SPFRecord]::new($splitString[$i],$splitString[$i + 1])
        }
    }
}
function Get-SPFRecord {
    <#
    .Synopsis
    Get SPF Record for a domain. If the include tag is present, recursively get that SPF Record, too.
    .DESCRIPTION
    This function uses Resolve-DNSName to recursively get the SPF Record for a given domain. Objects with a DomainName property,
    such as returned by Get-AcceptedDomain, can be piped to this function.
    .EXAMPLE
    Get-AcceptedDomain | Get-SPFRecord

    This example gets SPF records for all domains returned by Get-AcceptedDomain.
    #>
    [CmdletBinding(HelpUri = 'https://ntsystems.it/PowerShell/TAK/Get-SPFRecord/')]
    param (
        # Specify the Domain name for the query.
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true)]
        [string]
        $DomainName,
        
        # Specify the Domain name for the query.
        [string]
        $Server,

        [switch]
        $Recurse
    )
    process {
        $params = @{
            Type        = "txt"
            Name        = $DomainName
            ErrorAction = "Stop"
        }
        if ($Server) { $params.Add("Server", $Server) }
        try {
            $dns = Resolve-DnsName @params | Where-Object Strings -Match "spf1"
            $result = $dns | Select-Object @{Name = "DomainName"; Expression = { $_.Name } }, @{Name = "Record"; Expression = { $_.Strings } }
            if ($result.record -match "include:" -and $Recurse) {
                $include = Get-IncludedSpf($result.record)
                $include.where{$_.tag -eq "include"}.Value | ForEach-Object {
                    Write-Verbose "Found include: tag, looking up $_" 
                    Get-SPFRecord $_
                }
            }
            $result
        }
        catch {
            Write-Warning $_
        }
    }
}

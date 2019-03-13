function New-RgsReport {
    <#
    .SYNOPSIS
        Gather information about Skype for Business Response Groups, Queues, Agent Groups.
    .DESCRIPTION
        This function uses varios cmdlets of the Lync module (or an appropriate remote session) to 
        gather information about Response Groups.          
    .EXAMPLE
        PS C:\> Get-RgsReport -Filter Office -Path .\Desktop\report.csv 
        
        This example creates a CSV report for all RGS workflows matching Office. 
    .EXAMPLE
        PS C:\> Get-RgsReport -Filter Office -Path .\Desktop\report.html -Html
        
        This example creates a HTML report for all RGS workflows matching Office. 
    .EXAMPLE
        PS C:\> Get-RgsReport -Filter Office -Path .\Desktop\report.html -Html -PassThru | Out-GridView
        
        This example creates a HTML report for all RGS workflows matching Office, because the PassThru switch is present,
        the collected data will also be written to the pipeline. From there we can use it and pipe it to Out-GridView or do whatever.  
    .INPUTS
        None.
    .OUTPUTS
        [psobject]
    .NOTES
        Author: @torggler
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Filter,
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path,
        [Parameter()]
        [switch]
        $Html,
        [Parameter()]
        [switch]
        $PassThru
    )
    $data = Get-CsRgsWorkflow | Where-Object Name -Match $Filter | Select-Object -Property Name, LineUri, PrimaryUri, @{
        Name = "Queue";
        Expression = { 
            Get-CsRgsQueue -Identity $($_.DefaultAction.QueueId) | 
            Select-Object -ExpandProperty Name }
    }, @{
        Name = "Group";
        Expression = { (Get-CsRgsQueue -Identity $($_.DefaultAction.QueueId) | 
            Select-Object -ExpandProperty AgentGroupIDList | 
            ForEach-Object {Get-CsRgsAgentGroup -Identity $_.toString()} | 
            Select-Object -ExpandProperty Name) -join ", " }
    }, @{
        Name = "RoutingMethod";
        Expression = { (Get-CsRgsQueue -Identity $($_.DefaultAction.QueueId) | 
            Select-Object -ExpandProperty AgentGroupIDList | 
            ForEach-Object {Get-CsRgsAgentGroup -Identity $_.toString()} | 
            Select-Object -ExpandProperty RoutingMethod) -join ", " }
    }, @{
        Name = "Participation";
        Expression = { (Get-CsRgsQueue -Identity $($_.DefaultAction.QueueId) | 
            Select-Object -ExpandProperty AgentGroupIDList |
            ForEach-Object {Get-CsRgsAgentGroup -Identity $_.toString()} | 
            Select-Object -ExpandProperty ParticipationPolicy) -join ", " }
    }, @{
        Name = "Agents";
        Expression = { (Get-CsRgsQueue -Identity $($_.DefaultAction.QueueId) | 
            Select-Object -ExpandProperty AgentGroupIDList |
            ForEach-Object {Get-CsRgsAgentGroup -Identity $_.toString()} | 
            Select-Object -ExpandProperty AgentsByUri) -replace "sip:","" -replace "@.*$" -join ", " }
    }, @{
        Name = "DialPlan";
        Expression = { Get-CsApplicationEndpoint -Identity $_.PrimaryUri | Select-Object -ExpandProperty DialPlan }
    }, @{
        Name = "VoicePolicy";
        Expression = { Get-CsApplicationEndpoint -Identity $_.PrimaryUri | Select-Object -ExpandProperty VoicePolicy }
    }, Active, Anonymous, EnabledForFederation
    if($Html){
        $Head = "<style>
            table,th {font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif}
            th {text-align: left}
            table {margin-left: auto; margin-right: auto; display:block; width: 85%}
            tr:nth-child(even) {background: #CCC}
            tr:nth-child(odd) {background: #FFF}
        </style>"
        $data | ConvertTo-Html -Title "RGS Report" -Head $Head | Set-Content -Path $Path
    } else {
        $data | Export-Csv -Path $Path -NoTypeInformation -Delimiter ","
    }
    if($PassThru){
        $data
    }
}

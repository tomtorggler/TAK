
# using set-string for lack of a better fitting approved verb
function Set-String {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $String,
        $Replace
    )
    process {
        $string -replace $Replace
    }
}

function Split-String {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $String,
        $Pattern
    )
    process {
        $string -split $Pattern
    }
}


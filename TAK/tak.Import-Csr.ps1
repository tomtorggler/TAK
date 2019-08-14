function Import-Csr {
    <#
    .SYNOPSIS
        Import certificate signing request from base64 text.
    .DESCRIPTION
        This function uses the Windows Subsystem for Linux to invoke `openssl` to decode a certificate signing request.
    .EXAMPLE
        PS C:\> Import-Csr c:\temp\cert.req
        
        This example imports a CSR located at the given path and decodes it's contents.
    .INPUTS
        None
    .OUTPUTS
        [psobject]
    .NOTES
        Author: @torggler
        Date: 2019-06-14
    #>
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]
        $Path,
        [switch]
        $ShowText
    )
    if(Get-Command wsl -ErrorAction SilentlyContinue){
        Write-Verbose "Windows Path is $Path"
        $Path = $Path -replace "\\","\\\"
        $wslPath = Invoke-Expression "wsl wslpath -a $Path"
        Write-Verbose "Linux Path is $wslPath"
        $opensslOut = Invoke-Expression "wsl openssl req -in $wslPath -noout -text"

        New-Object -TypeName psobject -Property ([ordered]@{
            Subject = Get-SubjectFromCsr -InputObject $opensslOut
            SignatureAlgorithm = Get-SigAlgoFromCsr -InputObject $opensslOut
            KeyLength = Get-KeyLengthFromCsr -InputObject $opensslOut
            SAN = Get-SanFromCsr -InputObject $opensslOut
            KeyUsge = Get-KeyUsage -InputObject $opensslOut
            ExtendedKeyUsge = Get-EKeyUsage -InputObject $opensslOut
        })
        if($ShowText){
            $opensslOut 
        }
    } else {
        Write-Warning "Requires WSL."
    }
}

function Get-SubjectFromCsr($InputObject) {
    $subjectLine = $InputObject | Select-String -Pattern "Subject:" | Select-Object -ExpandProperty line
    $subjectLine.trimStart() -replace "Subject: ","" -split ", "    
}

function Get-SanFromCsr($InputObject) {
    $sanLine = $InputObject | Select-String -Pattern "X509v3 Subject Alternative Name:" -Context 0,1 | Select-Object -ExpandProperty context | Select-Object -ExpandProperty Postcontext
    $sanLine.trimStart() -split ", " -replace "DNS:",""
}

function Get-SigAlgoFromCsr($InputObject){
    $line = $InputObject | Select-String -Pattern "Signature Algorithm:" | Select-Object -ExpandProperty Line 
    $line.trimStart() -replace "Signature Algorithm: ",""
}

function Get-KeyLengthFromCsr($InputObject){
    $line = $InputObject | Select-String -Pattern "Public-Key: " | Select-Object -ExpandProperty Line
    $line.trimStart() -replace "Public-Key: ","" -replace "\(|\)",""
}

function Get-KeyUsage($InputObject){
    $line = $InputObject | Select-String -Pattern "X509v3 Key Usage: " -Context 0,1 | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty Postcontext
    $line.trimStart() -split ", "
}

function Get-EKeyUsage($InputObject){
    $line = $InputObject | Select-String -Pattern "X509v3 Extended Key Usage: " -Context 0,1 | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty Postcontext
    $line.trimStart() -split ", "
}

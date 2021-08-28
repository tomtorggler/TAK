
function Test-FederationService {
    <#
    .Synopsis
    Test the ADFS web service.
    .DESCRIPTION
    This function uses Invoke-RestMethod to test if the federation service metadata can be retrieved from a given server.
    .EXAMPLE
    Test-FederationService -ComputerName fs.uclab.eu 
    This example gets federation service xml information over the server fs.uclab.eu
    #>
    [CmdletBinding(HelpUri = 'https://onprem.wtf/PowerShell/Test-FederationService/')]
    param(
        # Specifies the name of the federation server 
        [Parameter(Mandatory=$true)]
        [validateLength(3,255)]
        [validatepattern("\w\.\w")]
        [string]
        [Alias("Server")]
        $ComputerName
    )

    $uri = "https://$ComputerName/FederationMetadata/2007-06/FederationMetadata.xml"
    # "adfs/ls/idpinitiatedsignon.htm"
    try {
        $webRequest = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        Write-Verbose $webRequest
    } catch {
        Write-Warning "Could not connect to $uri error $_"
        return
    }

    [byte[]]$rawData = [System.Convert]::FromBase64String($webRequest.EntityDescriptor.Signature.KeyInfo.X509Data.X509Certificate)
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.Import($rawData)
    
    $out = [ordered]@{
        "entityID" = $webRequest.entitydescriptor.entityID
        "xmlns" = $webRequest.entitydescriptor.xmlns
        "Roles" = @{
            "type" = $webRequest.entitydescriptor.RoleDescriptor.type
            "ServiceDisplayName" = $webRequest.entitydescriptor.RoleDescriptor.ServiceDisplayName
        }
        "IDPSSODescriptor" = $webRequest.EntityDescriptor.IDPSSODescriptor
        "SPSSODescriptor" = $webRequest.EntityDescriptor.SPSSODescriptor
        "SigningCert" = $certificate

    }
    # Create a custom object and add a custom TypeName for formatting before writing to pipeline
    Write-Output (New-Object -TypeName psobject -Property $out) 
}
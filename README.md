[![Build status](https://ci.appveyor.com/api/projects/status/4ihjpqd6c8f9cceq?svg=true)](https://ci.appveyor.com/project/tomtorggler/tak)

# TAK
Tom's Admin Kit - a collection of functions and snippets

# CI
I'm using appveyor.com to automatically run tests and, upon success, deploy the module to the PowerShell Gallery.

# Install
This module can be installed from the PowerShell Gallery, using: `Install-Module -Name TAK `

## Populate FunctionsToExport

The following snippet could be used to update the modules manifest file.

```powershell
Import-Module .\Git\TAK\TAK\tak.psm1
Import-Module .\Git\TAK\TAK\tak.exchange.psm1
$fn = Get-Command -Module tak | Where-Object CommandType -eq function | Where-Object HelpUri | Select-Object -ExpandProperty name
$fn += Get-Command -Module tak.exchange | Where-Object CommandType -eq function | Where-Object HelpUri | Select-Object -ExpandProperty name
"@("+($fn -join ",")+")"
```

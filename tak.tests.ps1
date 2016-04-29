$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$here\TAK\tak.psd1"

Describe "Test Converters" {
    Context "Testing Base64" {
        It "ConvertTo-Base64" {
            $base64 = ConvertTo-Base64 -String 'not so secret'
            $base64 | Should be 'bm90IHNvIHNlY3JldA=='
        }
        It "ConvertFrom-Base64" {
            $string = ConvertFrom-Base64 -String 'bm90IHNvIHNlY3JldA=='
            $string | Should be 'not so secret'
        }
        It "Test Piping From-To" {
            $string = 'bm90IHNvIHNlY3JldA=='
            ConvertFrom-Base64 -String $string | ConvertTo-Base64 | Should be $string
        }
        It "Test Piping To-From" {
            $string = 'not so secret'
            ConvertTo-Base64 -String $string | ConvertFrom-Base64 | Should be $string
        }
    }
    Context "Testing SID" {
        It "Verifing object type" {
            $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList s-1-5-32-544 
            $sid.IsValidTargetType([System.Security.Principal.NTAccount]) | Should be true
            $sid.IsValidTargetType([System.Security.Principal.SecurityIdentifier]) | Should be true
        }
        It "ConvertTo-SID" {
            $sid = ConvertTo-SID -SamAccountName 'BUILTIN\Administrators'
            $sid -is [string] | Should be true
            $sid | Should be 'S-1-5-32-544'
        }
        It "ConvertFrom-SID" {
            $username = ConvertFrom-SID -SID 'S-1-5-32-544'
            $username -is [string] | Should be true
            $username | Should be 'BUILTIN\Administrators'
        }
        It "Test Piping From-To" {
            $sid = 'S-1-5-32-544'
            ConvertFrom-SID -SID $sid | ConvertTo-SID | Should be $sid
        }
        It "Test Piping To-From" {
            $username = 'BUILTIN\Administrators'
            ConvertTo-SID -SamAccountName $username | ConvertFrom-SID | Should be $username
        }
        It "Verify parameter validation" {
            { ConvertFrom-SID -SID 123123 } | Should Throw
            
        }
    }
}

Describe "Test WebRequests" {
    Context "Testing MacAddressVendor" {
        It "Verify Web Request" {
            $Request = Invoke-WebRequest -Uri "http://www.macvendorlookup.com/api/BSDvICy/a0999b"
            $Request.StatusCode | Should be 200
        }
        It "Get-MacAddressVendor" {
            $result = Get-MacAddressVendor -MacAddress a0999b
            $result | Should not be $null
            $result.Vendor = 'Apple'
        }
    }
}

Describe "Test EtcHosts" {
    It "Show-EtcHosts Hostname" {
        $result = Show-EtcHosts | select -ExpandProperty HostName
        (-join $result) | Should match 'test1\.example\.com'
        (-join $result) | Should match 'test2\.example\.com'
    }
    It "Show-EtcHosts IPAddress" {
        $result = Show-EtcHosts | select -ExpandProperty IPAddress
        (-join $result) | Should match '10\.1\.1\.1'
        (-join $result) | Should match '192\.168\.1\.1'
    }
}
Remove-Module Tak
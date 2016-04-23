$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$here\tak.psd1"

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
    }
    Context "Testing SID" {
        It "ConvertTo-SID" {
            $sid = ConvertTo-SID -SamAccountName 'BUILTIN\Administrators'
            $sid | Should be 'S-1-5-32-544'
        }
        It "ConvertFrom-SID" {
            $username = ConvertFrom-SID -SID 'S-1-5-32-544'
            $username | Should be 'BUILTIN\Administrators'
        }
    }
}

Describe "Test WebRequests" {
    Context "Testing MacAddressVendor" {
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


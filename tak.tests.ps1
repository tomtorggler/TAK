$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$here
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
            $sid = ConvertTo-SID -SamAccountName 'Administrator'
            $sid | Should match 'S-1-5-\d{2}-\d{10}-\d{10}-\d{10}-500'
        }
        It "ConvertFrom-SID" {
            $sid = ConvertTo-SID -SamAccountName 'Administrator'
            $username = ConvertFrom-SID -SID $sid
            $username | Should match 'Administrator'
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
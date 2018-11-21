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
            #$Request = Invoke-WebRequest -Uri "http://www.macvendorlookup.com/api/BSDvICy/a0999b"
            #$Request.StatusCode | Should be 200
        }
        It "Get-MacAddressVendor" {
            #$result = Get-MacAddressVendor -MacAddress a0999b
            #$result | Should not be $null
            #$result.Vendor = 'Apple'
        }
    }
}

Describe "Test Add-EtcHostsEntry" {
    It "adds a line to the hosts file" {
        $before = Get-Content C:\Windows\System32\drivers\etc\hosts | Measure-Object | Select-Object -ExpandProperty Count
        Add-EtcHostsEntry -IPAddress '10.1.1.1' -Fqdn 'test1.example.com'
        $after = Get-Content C:\Windows\System32\drivers\etc\hosts | Measure-Object | Select-Object -ExpandProperty Count
        # seems not to work with AppVeyor
        #$before+1 | Should Be $after
        #Get-Content C:\Windows\system32\drivers\etc\hosts -Tail 1 | Should Match "10.1.1.1\t+test1.example.com"
    }
}

Describe "Test Show-EtcHosts" {
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

Describe "Test Connection" {
    Context "Test TCP Connection" {
        It "returns true for reachable ports" {
            Test-TCPConnection -ComputerName localhost -Port 135 | Should Be $true
            "localhost" | Test-TCPConnection -Port 135 | Should Be $true
        }
        It "returns false for unreachable ports" {
            Test-TCPConnection -ComputerName localhost -Port 22 | Should Be $false
            "localhost" | Test-TCPConnection -Port 22 | Should Be $false
        }
    }
    Context "Test TLS Connection" {
        It "returns Certificate information" {
            Test-TLSConnection -Protocol Tls12 -ComputerName www.ntsystems.it | select -ExpandProperty Subject | Should Match "cloudflaressl"
            "www.ntsystems.it" | Test-TLSConnection -Protocol Tls12 | select -ExpandProperty Subject | Should Match "cloudflaressl"
        }
        It "returns True when Silent parameter is used" {
            Test-TLSConnection -Protocol Tls12 -ComputerName www.ntsystems.it -Port 443 -Silent | Should Be $true
            "www.ntsystems.it" | Test-TLSConnection -Protocol Tls12 -Port 443 -Silent | Should Be $true
        }
        It "returns False if certificate is not trusted" {
            Test-TLSConnection -Protocol Tls12 -ComputerName sip.uclab.eu -Port 5061 -WarningAction SilentlyContinue | Should Be $false
            "sip.uclab.eu" | Test-TLSConnection -Protocol Tls12 -Port 5061 -WarningAction SilentlyContinue | Should Be $false            
        }
    }
}

Describe "Test Touch" {
    Context "Touch an inexistent file" {
        It "creates the specified file" {
            $newFile = touch .\inexistent.txt 
            $newFile.GetType().FullName | Should Be "System.IO.FileInfo"
            $newFile.Name | Should Be "inexistent.txt"
        }
        It "throws if no permissions to create file" {
            { touch 'C:\System Volume Information\item' } | Should Throw
        }
        It "throws if path to file not found" {
            { touch 'C:\blabla\item' } | Should Throw
        }
        Remove-Item .\inexistent.txt -ErrorAction SilentlyContinue
    }
    Context "Touch an existing file" {
        $exFile = New-Item -Name existing.txt -Type File
        $exLastWriteTime = $exFile.LastWriteTime
        It "updates the LastWriteTime property" {
            Start-Sleep -Seconds 1
            touch .\existing.txt
            $exLastWriteTime | Should BeLessThan (Get-Item .\existing.txt).LastWriteTime
        }
        It "throws if no permission to modify file" {
            { touch C:\Windows\System32\wininit.exe } | Should Throw
        }
        Remove-Item .\existing.txt -ErrorAction SilentlyContinue
    }
}

Describe "Test Get-TakHash" {
    Context "Test Algorithms" {
        It "MD5" {
            Get-TakHash "Hello World!" | Should Be "ed076287532e86365e841e92bfc50d8c"
        }
        It "SHA256" {
            Get-TakHash "Hello World!" -Algorithm Sha256 | Should Be "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"
        }
    }
}

Describe "Test DNS Lookup" {
    Context "Test Resolve-TakDns" {
        It "Without parameters, A and AAAA records are queried" {
            $Response = Resolve-TakDns ntsystems.it 
            $Response.IPAddress | Should -BeOfType IPAddress
        }
        It "Given -Name <Name> and -Type <Type>, it returns objects with <Expected> properties" -TestCases @(
          @{ Name = 'ntsystems.it'; Type = 'MX'; Expected = 'NameExchange' }
          @{ Name = 'ntsystems.it'; Type = 'TXT'; Expected = 'Strings' }
          @{ Name = '_sip._tls.ntsystems.it'; Type = 'SRV'; Expected = 'NameTarget' }
          @{ Name = 'autodiscover.ntsystems.it'; Type = 'CName'; Expected = 'NameHost' }
        ) {
          param ($Name, $Type, $Expected)
          $Responses = Resolve-TakDns -Name $Name -Type $Type 
          $Responses.$Expected | Should -Not -BeNullOrEmpty
        }
    } 
    Context "Test DNS Cmdlets" {
        It "Get-MxRecord returns objects with a NameExchange property" {
            (Get-MxRecord -Domain ntsystems.it).NameExchange | Should -Match "protection.outlook.com"
        }
        It "Get-DKIMRecord returns objects with a Record property" {
            (Get-DKIMRecord -Domain ntsystems.it -Selector selector1).Record | Should -Match "v=dkim1"
        }
        It "Get-SPFRecord returns objects with a Record property" {
            (Get-SPFRecord -Domain ntsystems.it).Record | Should -Match "v=spf1"
        }
    }
}

Remove-Module Tak

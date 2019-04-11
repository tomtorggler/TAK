function Get-InternetProxyAutoDetect {
    [CmdletBinding()]
    param()

    $Key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\" 
    $DefaultConnection = $(Get-ItemProperty $Key).DefaultConnectionSettings 

    if ($($DefaultConnection[8] -band 8) -ne 8) { 
        Write-Verbose "Auto Detection disabled for Default Connection"
        Write-Output $false 
    } else { 
        Write-Verbose "Auto Detection enabled for Default Connection"
        Write-Output $true 
    }
}

function Enable-InternetProxyAutoDetect {
    [CmdletBinding()]
    param()

    $Key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\" 
    $DefaultConnection = $(Get-ItemProperty $Key).DefaultConnectionSettings 

    $DefaultConnection[8] = $DefaultConnection[8] -bor 8 
    $DefaultConnection[4]++ 

    Write-Verbose "Enabling Proxy auto detection for Default Connection"
    Set-ItemProperty -Path $Key -Name DefaultConnectionSettings -Value $DefaultConnection 
}

function Disable-InternetProxyAutoDetect {
    [CmdletBinding()]
    param()

    $Key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\" 
    $DefaultConnection = $(Get-ItemProperty $Key).DefaultConnectionSettings 

    $mask = -bnot 8 
    $DefaultConnection[8] = $DefaultConnection[8] -band $mask 
    $DefaultConnection[4]++ 
    
    Write-Verbose "Disabling Proxy auto detection for Default Connection"
    Set-ItemProperty -Path $Key -Name DefaultConnectionSettings -Value $DefaultConnection 
}

function Get-InternetProxy {
    [CmdletBinding()]
    param()
    if ($IsLinux -or $IsMacOS) {
        New-Object -TypeName psobject -Property @{ http_proxy = $env:http_proxy }
        if (Test-Path /etc/proxy.pac) {
            Write-Verbose "/etc/proxy.pac found."
            Get-Content /etc/proxy.pac
        }
        else {
            Write-Verbose "/etc/proxy.pac not found."
        }
    } 
    else {
        $Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"        
        Get-ItemProperty -path $Key | Select-Object -Property ProxyEnable, ProxyServer, ProxyOverride, AutoConfigURL, @{N = "AutoDetect"; E = { Get-InternetProxyAutoDetect } }
        if ($ShowAutoConfig) {
            $path = Get-ItemProperty -path $Key | Select-Object -ExpandProperty AutoConfigURL
            if ($path -match "file:") {
                Get-Content -Path $($path.replace("file://", ""))
            }
        }               
    }    
}
Function Disable-InternetProxy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]
        $ClearAutoConfigUrl
    )
    if ($IsLinux -or $IsMacOS) {
        Remove-Item -path Env:/http*_proxy
    } 
    else {
        $Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"        
        Set-ItemProperty -Path $Key -Name ProxyEnable -Value 0
        Set-ItemProperty -Path $Key -Name ProxyServer -Value ""
        if ($ClearAutoConfigUrl0) {
            Set-ItemProperty -Path $Key -Name AutoConfigURL -Value ""
        }   
    }            
}
Function Enable-InternetProxy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]
        $ProxyServer = "localhost:8118",
        [string]
        $AutoConfigUrl
    )
    if ($IsLinux -or $IsMacOS) {
        New-Item -Path Env:/http_proxy -Value $ProxyServer
        New-Item -Path Env:/https_proxy -Value $ProxyServer
    }
    else {
        $Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"        
        if ($PSCmdlet.ShouldProcess($ProxyServer, "Set")) {
            Set-ItemProperty -Path $Key -Name ProxyEnable -Value 1
            Set-ItemProperty -Path $Key -Name ProxyServer -Value $ProxyServer
            if ($AutoConfigFile) {
                Set-ItemProperty -Path $Key -Name AutoConfigURL -Value $AutoConfigUrl
            }
        }
    }
}


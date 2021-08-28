Function ConvertFrom-IasLog {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    Begin {

        $FormatIAS = @{Expression = { $_.ComputerName }; Label = "ComputerName" }, `
        @{Expression = { $_.ServiceName }; Label = "ServiceName" }, `
        @{Expression = { $_."Record-Date" }; Label = "Record-Date" }, `
        @{Expression = { $_."Record-Time" }; Label = "Record-Time" }, `
        @{Expression = {
                switch ($_."Packet-Type") { 
                    1 { "Access-Request (1)" } 
                    2 { "Access-Accept (2)" } 
                    3 { "Access-Reject (3)" } 
                    4 { "Accounting-Request (4)" } 
                    5 { "Accounting-Response (5)" } 
                    11 { "Access-Challenge (11)" } 
                    12 { "Status-Server (experimental) (12)" } 
                    13 { "Status-Client (experimental) (13)" } 
                    "" { "" }
                    default { ($_) + " (unrecognized type)" } 
                }
            }; Label = "Packet-Type"
        }, `
        @{Expression = { $_."User-Name" }; Label = "User-Name" }, `
        @{Expression = { $_."Fully-Qualified-Distinguished-Name" }; Label = "Fully-Qualified-Distinguished-Name" }, `
        @{Expression = { $_."Called-Station-ID" }; Label = "Called-Station-ID" }, `
        @{Expression = { $_."Calling-Station-ID" }; Label = "Calling-Station-ID" }, `
        @{Expression = { $_."Callback-Number" }; Label = "Callback-Number" }, `
        @{Expression = { $_."Framed-IP-Address" }; Label = "Framed-IP-Address" }, `
        @{Expression = { $_."NAS-Identifier" }; Label = "NAS-Identifier" }, `
        @{Expression = { $_."NAS-IP-Address" }; Label = "NAS-IP-Address" }, `
        @{Expression = { $_."NAS-Port" }; Label = "NAS-Port" }, `
        @{Expression = { $_."Client-Vendor" }; Label = "Client-Vendor" }, `
        @{Expression = { $_."Client-IP-Address" }; Label = "Client-IP-Address" }, `
        @{Expression = { $_."Client-Friendly-Name" }; Label = "Client-Friendly-Name" }, `
        @{Expression = { $_."Event-Timestamp" }; Label = "Event-Timestamp" }, `
        @{Expression = { $_."Port-Limit" }; Label = "Port-Limit" }, `
        @{Expression = { $_."NAS-Port-Type" }; Label = "NAS-Port-Type" }, `
        @{Expression = { $_."Connect-Info" }; Label = "Connect-Info" }, `
        @{Expression = { $_."Framed-Protocol" }; Label = "Framed-Protocol" }, `
        @{Expression = { $_."Service-Type" }; Label = "Service-Type" }, `
        @{Expression = {
                switch ($_."Authentication-Type") { 
                    1 { "PAP (1)" } 
                    2 { "CHAP (2)" } 
                    3 { "MS-CHAP (3)" } 
                    4 { "MS-CHAP v2 (4)" } 
                    5 { "EAP (5)" } 
                    7 { "None (7)" } 
                    8 { "Custom (8)" }
                    11 { "PEAP (11)" }
                    "" { "" }
                    default { ($_) + " (unrecognized type)" } 
                }
            }; Label = "Authentication-Type"
        }, `
        @{Expression = { $_."Policy-Name" }; Label = "Policy-Name" }, `
        @{Expression = {
                switch ($_."Reason-Code") { 
                    0 { "IAS_SUCCESS (0)" }
                    1 { "IAS_INTERNAL_ERROR (1)" } 
                    2 { "IAS_ACCESS_DENIED (2)" } 
                    3 { "IAS_MALFORMED_REQUEST (3)" } 
                    4 { "IAS_GLOBAL_CATALOG_UNAVAILABLE (4)" } 
                    5 { "IAS_DOMAIN_UNAVAILABLE (5)" } 
                    6 { "IAS_SERVER_UNAVAILABLE (6)" } 
                    7 { "IAS_NO_SUCH_DOMAIN (7)" } 
                    8 { "IAS_NO_SUCH_USER (8)" } 
                    16 { "IAS_AUTH_FAILURE (16)" } 
                    17 { "IAS_CHANGE_PASSWORD_FAILURE (17)" } 
                    18 { "IAS_UNSUPPORTED_AUTH_TYPE (18)" } 
                    32 { "IAS_LOCAL_USERS_ONLY (32)" } 
                    33 { "IAS_PASSWORD_MUST_CHANGE (33)" } 
                    34 { "IAS_ACCOUNT_DISABLED (34)" } 
                    35 { "IAS_ACCOUNT_EXPIRED (35)" } 
                    36 { "IAS_ACCOUNT_LOCKED_OUT (36)" } 
                    37 { "IAS_INVALID_LOGON_HOURS (37)" } 
                    38 { "IAS_ACCOUNT_RESTRICTION (38)" } 
                    48 { "IAS_NO_POLICY_MATCH (48)" } 
                    64 { "IAS_DIALIN_LOCKED_OUT (64)" } 
                    65 { "IAS_DIALIN_DISABLED (65)" } 
                    66 { "IAS_INVALID_AUTH_TYPE (66)" } 
                    67 { "IAS_INVALID_CALLING_STATION (67)" } 
                    68 { "IAS_INVALID_DIALIN_HOURS (68)" } 
                    69 { "IAS_INVALID_CALLED_STATION (69)" } 
                    70 { "IAS_INVALID_PORT_TYPE (70)" } 
                    71 { "IAS_INVALID_RESTRICTION (71)" } 
                    80 { "IAS_NO_RECORD (80)" } 
                    96 { "IAS_SESSION_TIMEOUT (96)" } 
                    97 { "IAS_UNEXPECTED_REQUEST (97)" } 
                    "" { "" }
                    default { ($_) + " (unrecognized reason)" } 
                }
            }; Label = "Reason-Code"
        }, `
        @{Expression = { $_."Class" }; Label = "Class" }, `
        @{Expression = { $_."Session-Timeout" }; Label = "Session-Timeout" }, `
        @{Expression = { $_."Idle-Timeout" }; Label = "Idle-Timeout" }, `
        @{Expression = { $_."Termination-Action" }; Label = "Termination-Action" }, `
        @{Expression = { $_."EAP-Friendly-Name" }; Label = "EAP-Friendly-Name" }, `
        @{Expression = { $_."Acct-Status-Type" }; Label = "Acct-Status-Type" }, `
        @{Expression = { $_."Acct-Delay-Time" }; Label = "Acct-Delay-Time" }, `
        @{Expression = { $_."Acct-Input-Octets" }; Label = "Acct-Input-Octets" }, `
        @{Expression = { $_."Acct-Output-Octets" }; Label = "Acct-Output-Octets" }, `
        @{Expression = { $_."Acct-Session-Id" }; Label = "Acct-Session-Id" }, `
        @{Expression = { $_."Acct-Authentic" }; Label = "Acct-Authentic" }, `
        @{Expression = { $_."Acct-Session-Time" }; Label = "Acct-Session-Time" }, `
        @{Expression = { $_."Acct-Input-Packets" }; Label = "Acct-Input-Packets" }, `
        @{Expression = { $_."Acct-Output-Packets" }; Label = "Acct-Output-Packets" }, `
        @{Expression = { $_."Acct-Terminate-Cause" }; Label = "Acct-Terminate-Cause" }, `
        @{Expression = { $_."Acct-Multi-Ssn-ID" }; Label = "Acct-Multi-Ssn-ID" }, `
        @{Expression = { $_."Acct-Link-Count" }; Label = "Acct-Link-Count" }, `
        @{Expression = { $_."Acct-Interim-Interval" }; Label = "Acct-Interim-Interval" }, `
        @{Expression = { $_."Tunnel-Type" }; Label = "Tunnel-Type" }, `
        @{Expression = { $_."Tunnel-Medium-Type" }; Label = "Tunnel-Medium-Type" }, `
        @{Expression = { $_."Tunnel-Client-Endpt" }; Label = "Tunnel-Client-Endpt" }, `
        @{Expression = { $_."Tunnel-Server-Endpt" }; Label = "Tunnel-Server-Endpt" }, `
        @{Expression = { $_."Acct-Tunnel-Conn" }; Label = "Acct-Tunnel-Conn" }, `
        @{Expression = { $_."Tunnel-Pvt-Group-ID" }; Label = "Tunnel-Pvt-Group-ID" }, `
        @{Expression = { $_."Tunnel-Assignment-ID" }; Label = "Tunnel-Assignment-ID" }, `
        @{Expression = { $_."Tunnel-Preference" }; Label = "Tunnel-Preference" }, `
        @{Expression = { $_."MS-Acct-Auth-Type" }; Label = "MS-Acct-Auth-Type" }, `
        @{Expression = { $_."MS-Acct-EAP-Type" }; Label = "MS-Acct-EAP-Type" }, `
        @{Expression = { $_."MS-RAS-Version" }; Label = "MS-RAS-Version" }, `
        @{Expression = { $_."MS-RAS-Vendor" }; Label = "MS-RAS-Vendor" }, `
        @{Expression = { $_."MS-CHAP-Error" }; Label = "MS-CHAP-Error" }, `
        @{Expression = { $_."MS-CHAP-Domain" }; Label = "MS-CHAP-Domain" }, `
        @{Expression = { $_."MS-MPPE-Encryption-Types" }; Label = "MS-MPPE-Encryption-Types" }, `
        @{Expression = { $_."MS-MPPE-Encryption-Policy" }; Label = "MS-MPPE-Encryption-Policy" }, `
        @{Expression = { $_."Proxy-Policy-Name" }; Label = "Proxy-Policy-Name" }, `
        @{Expression = { $_."Provider-Type" }; Label = "Provider-Type" }, `
        @{Expression = { $_."Provider-Name" }; Label = "Provider-Name" }, `
        @{Expression = { $_."Remote-Server-Address" }; Label = "Remote-Server-Address" }, `
        @{Expression = { $_."MS-RAS-Client-Name" }; Label = "MS-RAS-Client-Name" }, `
        @{Expression = { $_."MS-RAS-Client-Version" }; Label = "MS-RAS-Client-Version" }
    }
    
    Process{
            $InputObject | Select-Object $FormatIAS
     
    }
}

Function Import-IasLog {
    param(
        [System.IO.FileInfo]
        $Path = "C:\Windows\System32\LogFiles",
        [int]$count = 1
    )
    $IASLogs = Get-ChildItem -Path $Path -Filter *.log | Select-Object -Last $count
        foreach($File in $IASLogs) {
            
            Get-Content -Path $File.fullname -Tail 100 | `
            ConvertFrom-Csv -Delimiter "," -Header ComputerName, ServiceName, Record-Date, Record-Time, Packet-Type, User-Name, Fully-Qualified-Distinguished-Name, Called-Station-ID, Calling-Station-ID, Callback-Number, Framed-IP-Address, NAS-Identifier, NAS-IP-Address, NAS-Port, Client-Vendor, Client-IP-Address, Client-Friendly-Name, Event-Timestamp, Port-Limit, NAS-Port-Type, Connect-Info, Framed-Protocol, Service-Type, Authentication-Type, Policy-Name, Reason-Code, Class, Session-Timeout, Idle-Timeout, Termination-Action, EAP-Friendly-Name, Acct-Status-Type, Acct-Delay-Time, Acct-Input-Octets, Acct-Output-Octets, Acct-Session-Id, Acct-Authentic, Acct-Session-Time, Acct-Input-Packets, Acct-Output-Packets, Acct-Terminate-Cause, Acct-Multi-Ssn-ID, Acct-Link-Count, Acct-Interim-Interval, Tunnel-Type, Tunnel-Medium-Type, Tunnel-Client-Endpt, Tunnel-Server-Endpt, Acct-Tunnel-Conn, Tunnel-Pvt-Group-ID, Tunnel-Assignment-ID, Tunnel-Preference, MS-Acct-Auth-Type, MS-Acct-EAP-Type, MS-RAS-Version, MS-RAS-Vendor, MS-CHAP-Error, MS-CHAP-Domain, MS-MPPE-Encryption-Types, MS-MPPE-Encryption-Policy, Proxy-Policy-Name, Provider-Type, Provider-Name, Remote-Server-Address, MS-RAS-Client-Name, MS-RAS-Client-Version | `
            ConvertFrom-IasLog
            
    }
}



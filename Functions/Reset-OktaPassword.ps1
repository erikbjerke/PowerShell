Function Reset-OktaPassword {
<#
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Okta username")]
        [string]$OktaUserName,
        [Parameter(Mandatory=$true,HelpMessage="Password")]
        [string]$Password
    )
    BEGIN {
        $uid = (oktaGetUserbyID -userName $OktaUserName).id
        $api_token = ""
        $headers = @{'accept'='application/json';'Content-Type'='application/json';'Authorization'="SSWS $api_token"}
        $json = '{
            "credentials": {
                "password" : { "value": "placeholder" }
                            }
                }'
        $pw = $json | ConvertFrom-Json
        $pw.credentials.password.value = $password
        $body = $pw | ConvertTo-Json
        $uri = "https://westernmilling.okta.com/api/v1/users/$uid"
    }
    PROCESS {
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
    }
    END {}

}

Reset-OktaPassword -OktaUserName json@test.com -Password "One Two 3 FOUR"

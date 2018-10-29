Function Unlock-OktaAccount {
    <#
    .SYNOPSIS
    Unlocks a user's Okta account
    .DESCRIPTION
    Unlocks a user's Okta account
    .PARAMETER OktaUserName
    Email address used to login into Okta
    .EXAMPLE
    Unlock-OktaAccount -OktaUserName someone@something.com
    #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,HelpMessage="Okta Username")]
            [Alias ('UserName')]
            [string]$OktaUserName                        
        )
        BEGIN {
            $uid = (oktaGetUserbyID -userName $OktaUserName).id            
        }
        PROCESS {
            oktaUnlockUserbyId -uid $uid
        }
        END {}
}
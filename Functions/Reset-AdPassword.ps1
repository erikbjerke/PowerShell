function Reset-AdPassword {
<#
.SYNOPSIS
Resets users AD password
.DESCRIPTION
Reset-AdPassword will reset a user's password with a random passphrase or a defined password. It will check if account
is locked out, and if it is will unlock it. Copies new password to clipboard and writes it to screen.
.PARAMETER User
Username of locked out account
.PARAMETER Password
If called, you can define a password. Defaults to a randomly generated passphrase pulled from the internet.
.EXAMPLE
Reset-AdPassword -User user
Resets password for user to a randomly generated passphrase
>EXAMPLE
Reset-AdPassword -User user -Password "B@dPa55w0rd"
Resets password for user to "B@dPa55w0rd".
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$User,
        [string]$Password = (Invoke-RestMethod -Method Get -Uri "https://makemeapassword.ligos.net/api/v1/passphrase/plain?pc=1&wc=3&whenUp=StartOfWord&ups=1&whenNum=StartOfWord&nums=1")
    )
    
    BEGIN {
        $LockedOut = (Get-ADUser $user).lockedout
    }
    
    PROCESS {        
        Set-ADAccountPassword -Identity $User -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)        
        if ($LockedOut = $true){                    
            Unlock-ADAccount $User                    
                }
    }
    
    END {
        $Password | clip
        $Password
    }
}


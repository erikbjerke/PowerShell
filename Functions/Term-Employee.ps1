Function Term-Employee {
<#
.SYNOPSIS
Changes terminated employee's password, syncs it to Office 365, and disables mobile device access. Sets email forwarding.
.DESCRIPTION
Term-Employee resets a terminated employee's password to a 20 character random password and syncs that password to Office 365. 
It also disables mobile access to email and can set a forwarding address for incoming emails. You do need to provide admin credentials for
both on premesis AD and Office 365.
.PARAMETER User
Username of terminated employee
.PARAMETER ForwardingAddress
Username of person to forward email to
.EXAMPLE
Term-Employee -User tuser -ForwardingAddress fuser
Resets tuser's password and locks out mobile devices. Forwards tuser's email to fuser.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$User,
        [string]$ForwardingAddress
    )
    BEGIN {
    $Password = -join(33..126 | foreach {[char]$_} | Get-Random -Count 20)
    $OnpremCred = Get-Credential -Message "Enter on prem domain credentials"
    $AzureADSync = New-PSSession -ComputerName ds01-prd-gsh -Credential $OnpremCred
    $OnlineCred = Get-Credential -Message "Enter Office 365 credentials"
    $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
    Import-PSSession $ExchangeOnline -DisableNameChecking -AllowClobber
    Import-Module Okta
    $OktaUser = (Get-ADUser $User -Properties mail).mail
    $uid = (oktaGetUserbyID -userName $OktaUser).id
    }
    PROCESS {
        Set-ADAccountPassword -Identity $User -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)

        Set-CASMailbox -Identity $User -ActiveSyncEnabled $false -OWAEnabled $false -OWAforDevicesEnabled $false
           

        If (-not ([string]::IsNullOrEmpty($ForwardingAddress))) {
    
            Set-Mailbox -Identity $User -ForwardingAddress $ForwardingAddress
           
        }

        Invoke-Command -Session $AzureADSync -ScriptBlock { 
            Start-AdSyncSyncCycle -PolicyType Initial
        }
        
        oktaDeactivateUserbyID -uid $uid        
    }
    END {
    Remove-PSSession -Name $AzureADSync
    Remove-PSSession -Name $ExchangeOnline
    }
}

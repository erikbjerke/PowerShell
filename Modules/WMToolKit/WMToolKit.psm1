#Western Milling Powershell Tool Kit

function New-MailEnabledUser {

    <#
    .SYNOPSIS
    Creates new mail enabled user and syncs it to Office 365
    .DESCRIPTION
    New-MailEnabledUser connects to es01-prd-gsh and creates a new remote mailbox and puts it in the correct OU.
    It grabs a random passphrase from an online generator. You can set it to require a password change after first login.
    It runs Azure AD Sync to create the mailbox in our Office 365 tenant. It waits for AAD sync to finish, then licenses
    It also sets the home drive path, home drive letter, logon script, and company name. Can copy AD group membership from another user.
    .PARAMETER FirstName
    First name of user
    .PARAMETER LastName
    Last name of user
    .PARAMETER UserName
    User name of user
    .PARAMETER OrganizationalUnit
    What OU to put the user in. Accepts 'OU' as an alias
    .PARAMETER LogonScript
    Specify which logon script to use. Accepts 'script' as an alias
    .PARAMETER License
    Specify which Office 365 license to use. Valid licenses are: "westernmilling:standardpack" and "westernmilling:enterprisepack".
    .PARAMETER Company
    Specify user's company. Valid companies are: "Western Milling", "Analytical Feed", "Hanford Grain Co","Western Foods", "Perfection Pet Foods", "OHK Logistics LLC", "Winema Elevators", "Western Innovations"
    .PARAMETER CopyGroupsFrom
    Specify a current user to copy group membership from.
    .PARAMETER ResetPasswordOnNextLogon
    If used, will force user to change password on next (first) logon
    .EXAMPLE
    New-MailEnabledUser -FirstName MailF -LastName Test -UserName mftest -OrganizationalUnit "westernmilling.com/Western Milling/Goshen/Users/IT/Test Accounts" -LogonScript "login.bat"
    Creates new remote mailbox for user 'MailF Test'. Puts it in the Test Accounts OU and gives it the login.bat logon script. Does not require a password change on first logon.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
    
         [Parameter(Mandatory=$true)]
        [string]$LastName,
    
        [Parameter(Mandatory=$true)]
         [string]$UserName,
    
        [Parameter(Mandatory=$true)]
        [Alias('OU')]
         [ValidateSet("westernmilling.com/Analytical Feed/Users", "westernmilling.com/Hanford Grain Company/Users", "westernmilling.com/OHKruse/Users", "westernmilling.com/Perfection Pet Foods/Users/Accounting", "westernmilling.com/Perfection Pet Foods/Users/Batching", "westernmilling.com/Perfection Pet Foods/Users/Consultants", "westernmilling.com/Perfection Pet Foods/Users/Executive", "westernmilling.com/Perfection Pet Foods/Users/Extrusion", "westernmilling.com/Perfection Pet Foods/Users/Maintenance", "westernmilling.com/Perfection Pet Foods/Users/Packaging", "westernmilling.com/Perfection Pet Foods/Users/Production", "westernmilling.com/Perfection Pet Foods/Users/QA", "westernmilling.com/Perfection Pet Foods/Users/Sales", "westernmilling.com/Perfection Pet Foods/Users/Salesforce", "westernmilling.com/Perfection Pet Foods/Users/Sanitation", "westernmilling.com/Perfection Pet Foods/Users/Warehouse", "westernmilling.com/Western Milling/Arizona/Users/", "westernmilling.com/Western Milling/Famoso/Users", "westernmilling.com/Western Milling/Grimes/Users", "westernmilling.com/Western Milling/Hanford/Users", "westernmilling.com/Western Milling/Modesto/Users", "westernmilling.com/Western Milling/Ontario/Users", "westernmilling.com/Western Milling/Goshen/Users/Accounting", "westernmilling.com/Western Milling/Goshen/Users/Adams", "westernmilling.com/Western Milling/Goshen/Users/Aero", "westernmilling.com/Western Milling/Goshen/Users/Credit Department", "westernmilling.com/Western Milling/Goshen/Users/Executive", "westernmilling.com/Western Milling/Goshen/Users/Finance", "westernmilling.com/Western Milling/Goshen/Users/Hay", "westernmilling.com/Western Milling/Goshen/Users/HR", "westernmilling.com/Western Milling/Goshen/Users/IT/Developers", "westernmilling.com/Western Milling/Goshen/Users/IT/Sys Admins", "westernmilling.com/Western Milling/Goshen/Users/IT/Test Accounts", "westernmilling.com/Western Milling/Goshen/Users/Liquids", "westernmilling.com/Western Milling/Goshen/Users/Maintenance", "westernmilling.com/Western Milling/Goshen/Users/Merchandising", "westernmilling.com/Western Milling/Goshen/Users/Mill", "westernmilling.com/Western Milling/Goshen/Users/Nutrition", "westernmilling.com/Western Milling/Goshen/Users/OHKT", "westernmilling.com/Western Milling/Goshen/Users/QA", "westernmilling.com/Western Milling/Goshen/Users/Safety", "westernmilling.com/Western Milling/Goshen/Users/Sales", "westernmilling.com/Western Milling/Goshen/Users/Truck Shop", "westernmilling.com/Western Milling/Goshen/Users/Weighmasters")]
         [string]$OrganizationalUnit,
    
        [Parameter(Mandatory=$true)]
        [Alias('Script')]
        [string]$LogonScript,
    
         [Parameter(Mandatory=$true)]
         [ValidateSet("westernmilling:STANDARDPACK","westernmilling:ENTERPRISEPACK")]
         [string]$License,
    
         [Parameter(Mandatory=$true)]
         [ValidateSet("Western Milling", "Analytical Feed", "Hanford Grain Co","Western Foods", "Perfection Pet Foods", "OHK Logistics LLC", "Winema Elevators", "Western Innovations")]
         [string]$Company,
            
        [string]$CopyGroupsFrom,
    
         [switch]$ResetPasswordOnNextLogon
     )
     BEGIN {
        $Password = Invoke-RestMethod -Method Get -Uri "https://makemeapassword.ligos.net/api/v1/passphrase/plain?pc=1&wc=3&whenUp=StartOfWord&ups=1&whenNum=StartOfWord&nums=1"
        $Name = $FirstName + ' ' + $LastName
        $UPN = $UserName + '@westernmilling.com'
        $HomePath = "\\wmfile.westernmilling.com\users\$UserName"
        $HomeDrive = "U:"
        $OnPremCred = Get-Credential -Message "Your Domain Admin Credentials"
        $OnPremExchange = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://es01-prd-gsh/powershell/ -Authentication Kerberos -Credential $OnPremCred
        $AzureADSync = New-PSSession -ComputerName ds01-prd-gsh -Credential $OnPremCred  
        $OnlineCred = Get-Credential -Message "Your Office 365 Admin Credentials"
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
                 
    }
    PROCESS {
        Import-PSSession $OnPremExchange -AllowClobber
        New-RemoteMailbox -Name "$Name" -FirstName $FirstName -LastName $LastName -Password (ConvertTo-SecureString -AsPlainText $Password -Force) -ResetPasswordOnNextLogon $ResetPasswordOnNextLogon -UserPrincipalName $UPN -OnPremisesOrganizationalUnit "$OrganizationalUnit"
        Remove-PSSession $OnPremExchange
    
        Invoke-Command -Session $AzureADSync -ScriptBlock {
                Start-AdSyncSyncCycle -PolicyType Initial
            }
        Remove-PSSession -Name $AzureADSync
    
        Set-ADUser -Identity $UserName -HomeDrive $HomeDrive -HomeDirectory $HomePath -ScriptPath $LogonScript -Company $Company
    
        Import-PSSession $ExchangeOnline -AllowClobber
        Connect-MsolService -Credential $OnlineCred
            
        do{
            "Waiting for Azure AD Sync to complete..."
            Start-Sleep -s 15
            $msolUser = Get-MsolUser -UserPrincipalName $UPN -ErrorAction SilentlyContinue
        }
        while ($msolUser -eq $null)
    
        Set-MsolUser -UserPrincipalName $UPN -UsageLocation US
        Set-MsolUserLicense -UserPrincipalName $UPN -AddLicenses $License
        Remove-PSSession $ExchangeOnline
    
        if (-not ([string]::IsNullOrEmpty($CopyGroupsFrom))) {
            Copy-GroupMembership -FromUser $CopyGroupsFrom -ToUser $UserName
        }
    
    }
    END {
        $UserPass = "Username: $UserName `nPassword: $Password"
        $UserPass | clip
        Write-Host "Username and Password have been copied to the clipboard"
        
    }
}
    
function Copy-GroupMembership {
<#
.SYNOPSIS
Copies group membership from one user to another
.DESCRIPTION
Copy-GroupMembership pulls the group membership from one user and then adds another user to each of those groups
.PARAMETER FromUser
Source user to copy groups from
.PARAMETER ToUser
Destination user to add to groups
.EXAMPLE
Copy-GroupMembership -FromUser auser -ToUser buser
#>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeLine=$true, HelpMessage="User to copy from")]
        [string]$FromUser,
        [Parameter(Mandatory=$true, HelpMessage="User to copy to")]
        [string]$ToUser
    )
    BEGIN {
        $groups = (Get-ADUser $FromUser -Properties memberof).memberof
    }
    PROCESS {
        foreach ($group in $groups) {
            Add-ADGroupMember -Identity $group -Members $ToUser
        }
    }
    END {}
}

function Get-LicenseExport {
<#
.SYNOPSIS
Exports Office 365 licensing info
.DESCRIPTION
Get-LicenseExport connects to our Exchange online tenant and the MSOL Service and exports the license type for licensed users into a CSV file.
If you specify a company, you'll only get the user licenses from that company. If you don't specify a company, it will pull all user licenses.
.PARAMETER CompanyName
Use the company name that is in AD, ex. "Perfection Pet Foods", "Hanford Grain Co", etc.
.PARAMETER FilePath
Name and location to put CSV file. Remember to add .csv to the end.
.EXAMPLE
Get-LicenseExport -CompanyName "Winema Elevators" -FilePath "C:\CSV\WELicenses.csv"
Pull license info for users with Winema Elevators as their company and save it C:\CSV\WELicenses.csv
.EXAMPLE
Get-LicenseExport -FilePath "C:\CSV\AllLicenses.csv"
Get all licensed users and export them to C:\CSV\AllLicenses.csv
#>    
    
    [CmdletBinding()]
    Param(
        #[Parameter(Mandatory=$true)]
        [string]$CompanyName,
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    BEGIN {
        $OnlineCred = Get-Credential ebjerke@westernmilling.com
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
        Import-PSSession $Session -DisableNameChecking -AllowClobber
        Connect-MsolService -Credential $OnlineCred
    }

    PROCESS {
        IF([string]::IsNullOrEmpty($CompanyName)) {
                $upns = (Get-MsolUser -all | where {$_.IsLicensed -eq $true}).userprincipalname
                }
                else {
                $upns = (get-aduser -Filter {Enabled -eq $true} -Properties Company | where {$_.company -eq "$CompanyName"}).userprincipalname
                }
            
            $licenseinfo = foreach ($upn in $upns){
                    Get-MsolUser -UserPrincipalName $upn | where {$_.IsLicensed -eq $true} | select UserPrincipalName,IsLicensed,{$_.Licenses.AccountSkuId}
                    }
            $licenseinfo | Export-Csv $FilePath -NoTypeInformation
            
            }
    END {
        Remove-PSSession $Session
    }
}
    
function Term-Employee {
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
    
function Cleanup-TermEmployee {
<#
.SYNOPSIS
Clean up term'd user's AD account
.DESCRIPTION
Cleanup-TermEmployee gets the group membership of the user, copies it to the clipboard, and then removes the user
from the groups. If the -MailEnabled switch is called, it will disable the remote mailbox, remove any Office 365 licenses,
and remove the MSOL user account from Office 365
.PARAMETER User
AD username
.PARAMETER MailEnabled
If called will remove all mail related attributes from user account
.EXAMPLE
Cleanup-TermEmployee -User auser -MailEnabled
Runs the entire function on auser.

#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter User Name")]
        [string]$User,
        [switch]$MailEnabled
    )
    BEGIN {
    
        $groups = (Get-ADUser $user -Properties memberof).memberof
        $DN = (Get-ADUser $user).DistinguishedName
        Get-ADPrincipalGroupMembership $user | where name -ne "Domain Users" | select Name | clip
        $UPN = $User + '@westernmilling.com'
    }

    PROCESS {

        If ($MailEnabled) {
            Write-Verbose "Connecting to OnPrem Exchange"
            $OnPremCred = Get-Credential -Message "Domain Admin Credentials"
            $OnPremExchange = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://es01-prd-gsh/powershell/ -Authentication Kerberos -Credential $OnPremCred
            Import-PSSession $OnPrem -AllowClobber
            Write-Verbose "Disabling Mailbox"
            Disable-RemoteMailbox $user -Confirm:$false
            Remove-PSSession $OnPremExchange
        }

        If ($MailEnabled) {
            Write-Verbose "Connecting to Exchange Online"
            $OnlineCred = Get-Credential -Message "Office 365 Admin Credentials"
            $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
            Import-PSSession $ExchangeOnline -AllowClobber
            Connect-MsolService -Credential $OnlineCred -al
            $Licenses = (Get-MsolUser -UserPrincipalName $UPN).Licenses.AccountSkuId
            Write-Verbose "Removing Office 365 License(s)"

            foreach ($License in $Licenses) {
                Set-MsolUserLicense -UserPrincipalName $UPN -RemoveLicenses $License
            }

            Write-Verbose "Removing MSOL User"
            Remove-MsolUser -UserPrincipalName $UPN -Force
            Remove-PSSession $ExchangeOnline
        }
        
        Write-Verbose "Removing user from AD groups"
        
        foreach ($group in $groups) {
            Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
        }
        
        Write-Verbose "Disabling AD account and moving object to Termninated Employees OU"
        Disable-ADAccount -Identity $DN
        Move-ADObject $DN -TargetPath "OU=Terminated Employees,DC=westernmilling,DC=com"
    }

    END {

    Write-Host "Account disabled. Group membership has been copied to the clipboard"
    
    }

}

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

function Remove-GroupMembership {
<#
.SYNOPSIS
Removes user from all AD groups
.DESCRIPTION
Remove-GroupMembership removes a user account from all of the AD groups it's a part of. Except domain users
#PARAMETER User
User name of account to remove from groups

#>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$User
    )
    BEGIN {
        $groups = (Get-ADUser $User -Properties memberof).memberof
    }
    PROCESS {
        foreach ($group in $groups) {
            Remove-ADGroupMember $group -Members $User -Confirm:$false
        }
    }
    END {}
}

Function Reset-OktaPassword {
<#
.SYNOPSIS
Resets Okta password and sets account to active
.DESCRIPTION
Resets Okta password and sets account to active
.PARAMETER OktaUserName
Email address used to login into Okta
.PARAMETER Password
Password string. Use quotation marks "" if the password has spaces in it. Password can't contain any part of the username
.EXAMPLE
Reset-OktaPassword -OktaUserName test@test.com -Password "One 2 THREE four"
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
        $api_token = "00cwdE_UsA6tOuiy-MfHscgWhUXJYf70Q9Vu1_QZX4"
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
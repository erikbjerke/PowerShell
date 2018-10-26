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

New-MailEnabledUser -FirstName Test1 -LastName Test1 -UserName ttest1 -OrganizationalUnit 'westernmilling.com/Western Milling/Ontario/Users' -LogonScript ppf.bat -License westernmilling:STANDARDPACK -Company 'Perfection Pet Foods' -CopyGroupsFrom ebjerke
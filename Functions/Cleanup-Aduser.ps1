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
            $OnPrem = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://es01-prd-gsh/powershell/ -Authentication Kerberos -Credential $OnPremCred
            Import-PSSession $OnPrem
            Write-Verbose "Disabling Mailbox"
            Disable-RemoteMailbox $user -Confirm:$false
            Remove-PSSession $OnPrem
        }

        If ($MailEnabled) {
            Write-Verbose "Connecting to Exchange Online"
            $OnlineCred = Get-Credential -Message "Office 365 Admin Credentials"
            $Online = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
            Import-PSSession $Online
            Connect-MsolService -Credential $OnlineCred
            $Licenses = (Get-MsolUser -UserPrincipalName $UPN).Licenses.AccountSkuId
            Write-Verbose "Removing Office 365 License(s)"

            foreach ($License in $Licenses) {
                Set-MsolUserLicense -UserPrincipalName $UPN -RemoveLicenses $License
            }

            Write-Verbose "Removing MSOL User"
            Remove-MsolUser -UserPrincipalName $UPN -Force
            Remove-PSSession $Online
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


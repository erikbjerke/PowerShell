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
        [Parameter(Mandatory=$true,ValueFromPipeline=$true, HelpMessage="User to copy from")]
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
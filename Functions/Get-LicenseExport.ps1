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
        Import-PSSession $Session -DisableNameChecking
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

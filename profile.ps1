New-PSDrive -Name scripts -PSProvider FileSystem -Root C:\Users\ebbb\Documents\WindowsPowerShell\Scripts
Import-Module WMToolKit
Import-Module Okta.Core.Automation
Import-Module Okta -Force
Connect-Okta -Token "00cwdE_UsA6tOuiy-MfHscgWhUXJYf70Q9Vu1_QZX4" -FullDomain "https://westernmilling.okta.com"
Set-Location c:\
$OnPremExchange = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://es01-prd-gsh/powershell/ -Authentication Kerberos -Credential $OnPremCred
$ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell-liveid -Credential $OnlineCred -Authentication Basic -AllowRedirection
$AzureADSync = New-PSSession -ComputerName ds01-prd-gsh -Credential $OnPremCred  

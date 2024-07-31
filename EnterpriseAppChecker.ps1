<#
This script gets any Enterprise Applications whose SAML signing cert is expiring within a given window.
The cert is stored as the keyCredential property in the service principal.
The keyCredentials property is used to configure an application’s authentication credentials.
#>

#How many days are left before a cert expires
$DaysTillExpiryThreshold = 60

Connect-MgGraph -Scopes Application.Read.All

#Get all service principals
$allSPs = Get-MgServicePrincipal -All | ?{$_.ServicePrincipalType -ne "ManagedIdentity"}

#Get only service principals that have key credentials
$SpsWithKeyCreds = $allSPs | Where-Object{$null -ne $_.KeyCredentials}
$ExpiringSPs = foreach ($SP in $SpsWithKeyCreds){
    foreach ($KeyCred in ($SP.KeyCredentials|Where-Object{$_.Usage -eq "Sign"})){
        $Time = (get-date).AddDays($DaysTillExpiryThreshold)
        if($KeyCred.EndDateTime -lt $Time -and $KeyCred.EndDateTime -gt (get-date)){
            Write-Output $SP
        }
    }
    
}

$ExpiringSPs
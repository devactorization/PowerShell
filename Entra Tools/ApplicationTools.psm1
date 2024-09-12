$AppsToIgnore =@(
    "P2P Server" #this is an app registration for PKU2U auth that is created when you join devices to Entra, can be ignored
    "Office 365 Exchange Online" #this has a KeyCredential object registered but is a Microsoft-managed application 
)

function GetServicePrincipals($ObjectId){

    if($ObjectId){
        $SPs = Get-MgServicePrincipal -ServicePrincipalId $ObjectId
    }
    else{
        #Get all Service Principals, excluding Managed Identities
        $AllSPs = Get-MgServicePrincipal -All | Where-Object{$_.ServicePrincipalType -ne "ManagedIdentity"}

        #Filter out apps we don't care about by DisplayName and filter out any that don't have credential objects
        $SPs = $AllSPs | Where-Object{$_.DisplayName -notin $AppsToIgnore} | Where-Object{($_.KeyCredentials -ne "") -or ($_.PasswordCredentials -ne "")}
    }
    Write-Output $SPs
}

function UpdateServicePrincipalNotificationEmail($App, $NotificationEmail){
    try{
        Write-Host -ForegroundColor Yellow "Updating app " $App.DisplayName
        Update-MgServicePrincipal -ServicePrincipalId $App.Id -NotificationEmailAddresses $NotificationEmail
        Write-Host -ForegroundColor Green "Successfully updated app " $App.DisplayName
    }
    catch{
        Write-Host -ForegroundColor Red "Failed to update app " $App.DisplayName
    }
}
function Get-ServicePrincipalNotificationAddresses {
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'All')]
        [switch]$All,
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleApp')]
        [string]$AppObjectId
    )

    if($All){
        $SPs = GetServicePrincipals
        $SPs | Format-Table DisplayName, Id, NotificationEmailAddresses
    }
    elseif($AppObjectId){
        $SP = GetServicePrincipals -ObjectId $AppObjectId
        $SP | Format-Table DisplayName, Id, NotificationEmailAddresses
    }
}

function Set-ServicePrincipalNotificationAddress{
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'All')]
        [switch]$All,
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleApp')]
        [string]$AppId,
        [Parameter(Mandatory = $true, ParameterSetName = 'All')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleApp')]
        [string]$NotificationEmail
    )

    if($All){
        $SPs = GetServicePrincipals
        foreach ($App in $SPs){
            UpdateServicePrincipalNotificationEmail -App $App -NotificationEmail $NotificationEmail
        }
    }
    elseif($AppId){
        $App = Get-MgApplication -ApplicationId $AppId
        UpdateServicePrincipalNotificationEmail -App $App -NotificationEmail $NotificationEmail
    }
}

function Get-AppCredentialExpirations{
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysTillExpiryThreshold
    )
    
    $AllApps = Get-MgApplication

    $AppCredObjs = @()
    foreach($App in $AllApps){
        $AppName = $App.DisplayName
        $AppID   = $App.Id
        $ApplID  = $App.AppId
    
        $AppCreds = Get-MgApplication -ApplicationId $AppID | Select-Object PasswordCredentials, KeyCredentials
    
        $Secrets = $AppCreds.PasswordCredentials
        $Certs   = $AppCreds.KeyCredentials
    
        foreach ($Secret in $Secrets) {
            $StartDate  = $Secret.StartDateTime
            $EndDate    = $Secret.EndDateTime
            $SecretName = $Secret.DisplayName
    
            $AppCredObjs += [PSCustomObject]@{
                'ApplicationName'        = $AppName
                'ApplicationID'          = $ApplID
                'Credential Type'        = "Secret"
                'Credential Name'        = $SecretName
                'Credential Start Date'  = $StartDate
                'Credential End Date'    = $EndDate
            }
        }
    
        foreach ($Cert in $Certs) {
            $StartDate = $Cert.StartDateTime
            $EndDate   = $Cert.EndDateTime
            $CertName  = $Cert.DisplayName
    
            $AppCredObjs += [PSCustomObject]@{
                'ApplicationName'        = $AppName
                'ApplicationID'          = $ApplID
                'Credential Type'        = "Certificate"
                'Credential Name'        = $CertName
                'Credential Start Date'  = $StartDate
                'Credential End Date'    = $EndDate
            }
        }
    }

    if($DaysTillExpiryThreshold){
        $UpcomingExpirations = $AppCredObjs | Where-Object{$_.'Credential End Date' -lt (get-date).AddDays($DaysTillExpiryThreshold)}
        Write-Output $UpcomingExpirations
    }
    else{
        Write-Output $AppCredObjs
    }   
}

Export-ModuleMember Get-ServicePrincipalNotificationAddresses, Set-ServicePrincipalNotificationAddress, Get-AppCredentialExpirations
<#
    .SYNOPSIS
    Lists or updates notification emails for Entra service principals that have SAML signing certs

    .DESCRIPTION
    This script is used for discovering and, optionally, updating the notification email for service principals (i.e. Enterprise Applications) in Entra that are configured with SAML signing certs (stored as KeyCredential objects).
    When you create a KeyCredential object (SAML signing cert) it automatically sets the notification email to the primary SMTP address of the account which created the app.
    This script can be used to update the email addresses to a centralized alert/notification DL.

    .PARAMETER List
    Lists apps with

    .PARAMETER Update
    Updates the notification email for applications, requires the NotificationEmail parameter be specified as well. Defaults to updating ALL apps that are configured for SAML auth.

    .PARAMETER NotificationEmail
    Email address to update service principals' to use.

    .PARAMETER ChooseApps
    Optional, prompts for selection of service principals to update via Out-Gridview. Without this, ALL apps will be updated by the Update flag.

    .PARAMETER Force
    Skips confirmation dialogue (e.g. for use in automation/other scripts). Use at your own risk!

    .INPUTS
    None.

    .OUTPUTS
    Array of service principal objects, only outputs certain properties.

    .EXAMPLE
    PS> Get-ServicePrincipalNotifications -List

    .EXAMPLE
    PS> Get-ServicePrincipalNotifications -Update -NotificationEmail user@contoso.com

    .EXAMPLE
    PS> Get-ServicePrincipalNotifications -Update -NotificationEmail user@contoso.com -ChooseApps
#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = 'List', Position = 0)]
    [switch]$List,
    [Parameter(Mandatory = $true, ParameterSetName = 'Update', Position = 0)]
    [switch]$Update,
    [Parameter(Mandatory = $true, ParameterSetName = 'Update', Position = 1)]
    [string]$NotificationEmail,
    [Parameter(Mandatory = $false, ParameterSetName = 'Update', Position = 2)]
    [switch]$ChooseApps,
    [Parameter(Mandatory = $false, ParameterSetName = 'Update', Position = 3)]
    [switch]$Force
)

#List of apps to ignore based on DisplayName attribute
$AppsToIgnore =@(
    "P2P Server" #this is an app registration for PKU2U auth that is created when you join devices to Entra, can be ignored
)

############### Script Below ###############

function GetServicePrincipals{
    #Get all Service Principals, excluding Managed Identities, and filter out ones without KeyCredentials for signing since those don't need to have notification emails set
    $AllSPs = Get-MgServicePrincipal -All | Where-Object{$_.ServicePrincipalType -ne "ManagedIdentity"} | Where-Object{$_.KeyCredentials.Usage -eq "Sign"}

    #Filter out apps we don't care about by DisplayName
    $SPs = $AllSPs | Where-Object{$_.DisplayName -notin $AppsToIgnore}

    Write-Output $SPs
}

function UpdateServicePrincipalNotificationEmail($App){
    try{
        Write-Host -ForegroundColor Yellow "Updating app " $App.DisplayName
        Update-MgServicePrincipal -ServicePrincipalId $App.Id -NotificationEmailAddresses $NotificationEmail
        Write-Host -ForegroundColor Green "Successfully updated app " $App.DisplayName
    }
    catch{
        Write-Host -ForegroundColor Red "Failed to update app " $App.DisplayName
    }
}

if ($List){
    Connect-MgGraph -Scopes "Application.Read.All" -NoWelcome

    Write-Host -ForegroundColor Green "Getting service principals, this may take a while..."
    $FilteredSPs = GetServicePrincipals

    $FilteredSPs | Format-Table DisplayName,Id,NotificationEmailAddresses,ServicePrincipalType
}

elseif($Update){
    if(!$ChooseApps -and !$Force){
        Write-Host -ForegroundColor Red "WARNING: you are updating all apps. Please confirm that you understand this and want to continue..."
        $Answer = Read-Host -Prompt "Continue (Y/N)?"
        if($Answer -ne "y"){Exit}

        Connect-MgGraph -Scopes "Application.ReadWrite.All" -NoWelcome

        $FilteredSPs = GetServicePrincipals

        foreach ($App in $FilteredSPs){
            UpdateServicePrincipalNotificationEmail($App)
        }
    }
    elseif ($ChooseApps) {
        Write-Host -ForegroundColor Red "WARNING: you are updating the notification email for applications. Please confirm that you understand this and want to continue..."
        $Answer = Read-Host -Prompt "Continue (Y/N)?"
        if($Answer -ne "y"){Exit}

        Connect-MgGraph -Scopes "Application.ReadWrite.All" -NoWelcome

        Write-Host -ForegroundColor Green "Getting service principals, this may take a while..."
        $FilteredSPs = GetServicePrincipals
        Write-Host -ForegroundColor Yellow "Please select apps to update in out-gridview window"
        $ChosenSPs = $FilteredSPs | Select-Object DisplayName,Id,AppId,NotificationEmailAddresses,ServicePrincipalType | Out-GridView -OutputMode Multiple -Title "Choose Applications to Update"

        foreach ($App in $ChosenSPs){
            UpdateServicePrincipalNotificationEmail($App)
        }
    }

    Write-Host -ForegroundColor Green "Completed."
}

Disconnect-MgGraph | Out-Null
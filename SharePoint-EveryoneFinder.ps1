# This script finds SharePoint sites with the "everyone except external users" permission
# Please note that this script may take several hours to run

Import-Module pnp.powershell

# Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP PowerShell" -Tenant TENANT.onmicrosoft.com -Interactive
$ClientId = "<ID>"

#Parameters
$SiteURL = "https://<TENANT-ADMIN>.sharepoint.com/"

$ReportOutput = "C:\Temp\SitePermissionsReport.csv"


Connect-PnPonline -Url $SiteURL -OSLogin -ClientId $ClientId
$TenantID = Get-PnPTenantId
$SearchGroupID = "spo-grid-all-users/$TenantID" #Everyone except external users

$Sites = Get-PnPTenantSite

$Results = @()
$ProgressTotal = $Sites.count
$ProgressCounter = 0
foreach ($Site in $Sites){
    Connect-PnPonline -Url $Site.Url -OSLogin -ClientId $ClientId
    Write-Host "Checking: " $Site.Title
    $Groups = Get-PnPSiteGroup | Where-Object { $_.Users -contains $SearchGroupID }
    If($Groups)
    {
        $Results += [PSCustomObject]@{
            SiteName         = $Site.Title
            URL              = $Site.URL
            Permissions      = "Group(s): $($Groups.Title -join "; ")"
        }
    }
    Else
    {
        #Check if the site (or its objects) contains any Direct permissions to "Everyone except external users"
        $EEEUsers = Get-PnPUser -WithRightsAssigned  | Where-Object {$_.Title -eq "Everyone except external users"}
 
        If($EEEUsers)
        {
            $Results += [PSCustomObject]@{
                SiteName         = $Site.Title
                URL              = $Site.URL
                Permissions      = "Direct Permissions"
            }        
        }
    }
    $Percentage = (($ProgressCounter / $ProgressTotal)*100)
    Write-Progress -PercentComplete $Percentage -Activity "checking sites"
    $ProgressCounter++
}

$Results | Export-Csv $ReportOutput
#$Results | Format-Table
#$ResultsBackup = $Results


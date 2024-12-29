param(
    [string]$TargetFolder
)

$ModulePath = "$PSScriptRoot\$TargetFolder"
Publish-PSResource -Path $ModulePath -ApiKey $Env:APIKEY

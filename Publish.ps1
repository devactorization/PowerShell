param(
    [string]$TargetFolder
)

Write-Verbose "Publishing module at path: $TargetFolder"
ls
Write-Verbose "Testing path..."
Test-Path $TargetFolder

$ModulePath = "$PSScriptRoot\$TargetFolder"
Publish-PSResource -Path $ModulePath -ApiKey $Env:APIKEY

<#
Written by Don Morgan
This module exposes the Business Central API via native PowerShell commands
#>

########## Begin Internal functions ##########
function GetOauthToken{
    #Get access token - note that the token has a 1h lifetime
    #Docs on getting an auth token using an app secret: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#first-case-access-token-request-with-a-shared-secret
    #Business Central API: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/automation-apis-using-s2s-authentication
    #More API docs: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/
    #Note: if this ever needs to be set up again, there are steps inside the Business Central cient that need to be taken to add the user
    #Note: the body of the POST request is NOT json
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        [Parameter(Mandatory = $true)]
        [string]$TenantId
    )

    $bodyParts = @(
        "grant_type=client_credentials",
        "client_id=$ClientId",
        "client_secret=$ClientSecret",
        "scope=https://api.businesscentral.dynamics.com/.default"
    )
    $body =  $bodyParts | Join-String -Separator "&"

    $headers = @{}
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")

    $authUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $req = Invoke-WebRequest -Uri $authUri -Method Post -Body $body -Headers $headers

    $OauthToken = ($req.Content|ConvertFrom-Json).access_token

    Return $OauthToken
}

function InvokeBusinessCentralApi{
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('/.*')] #require the endpoint start with '/'
        [string]$Endpoint,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Get","Post","Delete","Patch")]
        [string]$Method = "get",
        [Parameter(Mandatory = $false)]
        $Body,
        [Parameter(Mandatory = $false)]
        [switch]$NoCompanyContext
    )

    if($null -eq $env:BusinessCentralApiToken){
        throw 'please run the "Connect-BusinessCentralApi" cmdlet first'
    }
    if($null -eq $env:BusinessCentralApiEnvironmentContext){
        throw 'please set an environment using the "Set-BusinessCentralEnvironmentContext" cmdlet first'
    }


    $Environment = $env:BusinessCentralApiEnvironmentContext
    $Company = $env:BusinessCentralApiCompanyContext

    if($NoCompanyContext){
        $ApiBaseUrl = "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/v2.0"    
    }
    else{
        $ApiBaseUrl = "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/v2.0/companies($Company)"
    }

    $ApiUrl = $ApiBaseUrl + $Endpoint

    if($env:BusinessCentralApiVerbosity -eq "debug"){
        Write-Host -ForegroundColor Yellow "Business Central environment: $env:BusinessCentralApiEnvironmentContext"
        Write-Host -ForegroundColor Yellow "API endpoint being called: $Method $ApiUrl"
        Write-Host -ForegroundColor Yellow "API call body: $Body"
    }

    $Token = $env:BusinessCentralApiToken
    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/json"
        "Content-Type" = "application/json"
    }

    if($Method -eq "Get"){
        $Request = (Invoke-WebRequest -Uri $ApiUrl -Method Get -Headers $headers).content | Convertfrom-Json
    }
    elseif($Method -eq "Post"){
        $Request = Invoke-WebRequest -Uri $ApiUrl -Method Post -Headers $headers -Body $Body
    }
    elseif($Method -eq "Delete"){
        $Request = Invoke-WebRequest -Uri $ApiUrl -Method Delete -Headers $headers
    }
    elseif($Method -eq "Patch"){
        #Need to add the if-match header as it's required for patch calls (updating objects)
        #Seems this is due to potential caching in webservers:
        #https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Match
        $headers.Add("If-Match", '*')
        $Request = Invoke-WebRequest -Uri $ApiUrl -Method Patch -Headers $headers -Body $Body
    }
    
    Return $Request
}
########## End Internal Functions ##########

#Debugging cmdlet
function Set-BusinessCentralApiVerbosity{
    param(
        [bool]$Debug
    )

    if($Debug){
        $env:BusinessCentralApiVerbosity = "debug"
        Write-Host -ForegroundColor Green "Business Central debug mode enabled"
    }
    else{
        $env:BusinessCentralApiVerbosity = $null
        Write-Host -ForegroundColor Yellow "Business Central debug mode disabled"
    }
}


#Tenant level/general cmdlets
function Connect-BusinessCentralApi{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        [Parameter(Mandatory = $true)]
        [string]$TenantId
    )

    try{
        $OauthToken = GetOauthToken -ClientSecret $ClientSecret -ClientId $ClientId -TenantId $TenantId
    }
    catch{
        Write-Error "Failed to get Oauth token"
    }

    $env:BusinessCentralApiToken = $OauthToken
    Write-Host -ForegroundColor Green "Connected - API token good for one hour."
}
function Get-BusinessCentralEnvironment{
    #This cmdlet doesn't use InvokeBusinessCentralApi since it uses the admin API instead of the normal/application API
    #Get a list of environments using the admin center API
    param(
        [switch]$Current
    )

    #Get currently set environment
    if($Current){
        return $env:BusinessCentralApiEnvironmentContext
    }
    #list all environments
    else{
        $Token = $env:BusinessCentralApiToken
        $headers = @{
            Authorization = "Bearer $Token"
            Accept        = "application/json"
            "Content-Type" = "application/json"
        }
    
        $environmentsApiUrl = "https://api.businesscentral.dynamics.com/admin/v2.21/applications/environments"
        $environments = (Invoke-WebRequest -Uri $environmentsApiUrl -Method GET -Headers $headers).content | Convertfrom-Json
    
        Return $environments.value
    }

}
function Set-BusinessCentralEnvironmentContext{
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )

    $env:BusinessCentralApiEnvironmentContext = $EnvironmentName
    Write-Host -ForegroundColor Green "Set Business Central API environment context to $EnvironmentName"
}
function Set-BusinessCentralCompanyContext{
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
    )

    $env:BusinessCentralApiCompanyContext = $CompanyId
    Write-Host -ForegroundColor Green "Set Business Central API company context to $CompanyId"
}

#Object level cmdlets

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_company
function Get-BusinessCentralCompany{
    $CompanyEndpoint = "/companies"

    $Companies = InvokeBusinessCentralApi -Endpoint $CompanyEndpoint -NoCompanyContext

    Return $Companies.value
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_get
function Get-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $false)]
        [string]$Id
    )

    $CustomerEndpoint = "/customers"
    if($Id){
        $CustomerEndpoint += "($Id)"
    }

    $Customers = InvokeBusinessCentralApi -Endpoint $CustomerEndpoint

    if($Id){
        Return $Customers
    }
    else{
        Return $Customers.value
    }   
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_create
function New-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Company","Person")]
        [string]$Type,
        #Optional fields below here
        [string]$AddressLine1,
        [string]$AddressLine2,
        [string]$City,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$State,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$Country,
        [string]$PostalCode,
        [string]$PhoneNumber,
        [string]$Email,
        [string]$Website,
        [string]$salespersonCode
    )

    #Dynamically create a hashtable with whatever attributes were specified. Have to do this since you can't have a null key value in hashtables and you may not use all params when creating a new object
    $Attributes = @{}
    $Params = $PSBoundParameters
    $Keys = $PsBoundParameters.Keys
    foreach ($Key in $Keys){
        $Attributes.Add($Key,$Params.$Key)
    }

    $Body = $Attributes | ConvertTo-Json

    $CustomerEndpoint = "/customers"

    $Request = InvokeBusinessCentralApi -Endpoint $CustomerEndpoint -Method Post -Body $Body

    Return $Request.content | ConvertFrom-Json
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_delete
function Remove-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $CustomerEndpoint = "/customers($Id)"

    $Request = InvokeBusinessCentralApi -Endpoint $CustomerEndpoint -Method Delete

    if($Request.StatusCode -ne '204'){
        Write-Error "Failed to delete customer $Request"
    }
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_update
function Set-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        #Optional fields below here
        [string]$Number,
        [string]$DisplayName,
        [ValidateSet("Company","Person")]
        [string]$Type,
        [string]$AddressLine1,
        [string]$AddressLine2,
        [string]$City,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$State,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$Country,
        [string]$PostalCode,
        [string]$PhoneNumber,
        [string]$Email,
        [string]$Website,
        [string]$salespersonCode
    )

    #Dynamically create a hashtable with whatever attributes were specified. Have to do this since you can't have a null key value in hashtables and you may not use all params when creating a new object
    $Attributes = @{}
    $Params = $PSBoundParameters
    $Keys = $PsBoundParameters.Keys
    foreach ($Key in $Keys){
        $Attributes.Add($Key,$Params.$Key)
    }

    $Body = $Attributes | ConvertTo-Json

    $CustomerEndpoint = "/customers($Id)"

    $Request = InvokeBusinessCentralApi -Endpoint $CustomerEndpoint -Method Patch -Body $Body

    if($Request.StatusCode -ne '200'){
        Write-Error "Failed to update customer $Request"
    }
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_get
function Get-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $false)]
        [string]$Id
    )

    If($Id){
        $ContactEndpoint = "/contacts($Id)"
        
    }
    else{
        $ContactEndpoint = "/contacts"
    }

    $Request = InvokeBusinessCentralApi -Endpoint $ContactEndpoint

    if($Id){
        Return $Request    
    }
    else{
        Return $Request.value
    }
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_create
function New-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Number,
        #Optional fields below here
        [string]$AddressLine1,
        [string]$AddressLine2,
        [string]$City,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$State,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$Country,
        [string]$PostalCode,
        [string]$PhoneNumber,
        [string]$MobilePhoneNumber
    )

    #Dynamically create a hashtable with whatever attributes were specified. Have to do this since you can't have a null key value in hashtables and you may not use all params when creating a new object
    $Attributes = @{}
    $Params = $PSBoundParameters
    $Keys = $PsBoundParameters.Keys
    foreach ($Key in $Keys){
        $Attributes.Add($Key,$Params.$Key)
    }

    $Body = $Attributes | ConvertTo-Json

    $CustomerEndpoint = "/contacts"

    $Request = InvokeBusinessCentralApi -Endpoint $CustomerEndpoint -Method Post -Body $Body

    Return $Request.content | ConvertFrom-Json
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_delete
function Remove-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $ContactEndpoint = "/contacts($Id)"

    $Request = InvokeBusinessCentralApi -Endpoint $ContactEndpoint -Method Delete

    if($Request.StatusCode -ne '204'){
        Write-Error "Failed to delete contact $Request"
    }
}

#https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_update
function Set-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        #Optional fields below here
        [string]$DisplayName,
        [string]$Number,
        [string]$AddressLine1,
        [string]$AddressLine2,
        [string]$City,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$State,
        [ValidatePattern('[A-Z][A-Z]')]
        [string]$Country,
        [string]$PostalCode,
        [string]$PhoneNumber,
        [string]$MobilePhoneNumber
    )

    #Dynamically create a hashtable with whatever attributes were specified. Have to do this since you can't have a null key value in hashtables and you may not use all params when creating a new object
    $Attributes = @{}
    $Params = $PSBoundParameters
    $Keys = $PsBoundParameters.Keys
    foreach ($Key in $Keys){
        $Attributes.Add($Key,$Params.$Key)
    }

    $Body = $Attributes | ConvertTo-Json

    $ContactsEndpoint = "/contacts($Id)"

    $Request = InvokeBusinessCentralApi -Endpoint $ContactsEndpoint -Method Patch -Body $Body

    if($Request.StatusCode -ne '200'){
        Write-Error "Failed to update contact $Request"
    }
}
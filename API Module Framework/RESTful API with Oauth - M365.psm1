<#
Template code - written by Don Morgan, October 2024

This template is for RESTful APIs which use Microsoft Entra ID for OAuth authentication using app registrations.

Change the following bits and pieces to customize it to your API:
- cmdlet nouns
- API endpoints in each cmdlet
- Base API URL in the "InvokeModuleApi" internal function
- Error messages in the "InvokeModuleApi" internal function (they reference the sample cmdlet names)


Notes:
- "Get" cmdlets are generally written to be able to get either all objects (e.g. get all customers) or a specific one, by ID
- Generally, a given cmdlet is just changing the API endpoint that is called, and maybe has an arbitrary object passed as the body. This allows the InvokeModuleApi internal function to be called and enables good code re-usability.
- For "Set" cmdlets, the parameters will vary and sometimes not all parameters will be used, e.g. if you are creating a new contact and specifying a phone number but not a country code. This is why I use the $PSBoundParameters automatic variable and a nifty trick to dynamically build the hashtable which ultimately is converted to JSON and passed as the body of the API call. Also note that in this example, the API endpoint for creating a new contact includes a company ID so that parameter is not included in the dynamically generated hashtable/body.

#>

########## Begin Internal functions ##########
function GetOauthToken{
    #Get access token - note that the token has a 1h lifetime
    #Docs on getting an auth token using an app secret: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#first-case-access-token-request-with-a-shared-secret
    #Business Central API: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/automation-apis-using-s2s-authentication
    #Note: There are steps inside the Business Central cient that need to be taken to add the user permissions for the app registration
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
        "scope=https://api.businesscentral.dynamics.com/.default" #Change as needed for whatever resource/API you're using
    )
    $body =  $bodyParts | Join-String -Separator "&"

    $headers = @{}
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")

    $authUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $req = Invoke-WebRequest -Uri $authUri -Method Post -Body $body -Headers $headers

    $OauthToken = ($req.Content|ConvertFrom-Json).access_token

    Return $OauthToken
}

function InvokeModuleApi{
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('/.*')] #require the endpoint start with '/'
        [string]$Endpoint,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Get","Post")]
        [string]$Method = "get",
        [Parameter(Mandatory = $false)]
        $Body
    )

    if($null -eq $env:BusinessCentralApiToken){
        throw 'please run the "Connect-BusinessCentralApi" cmdlet first'
    }
    if($null -eq $env:BusinessCentralApiEnvironmentContext){
        throw 'please set an environment using the "Set-BusinessCentralEnvironmentContext" cmdlet first'
    }

    $Environment = $env:BusinessCentralApiEnvironmentContext
    $ApiBaseUrl = "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/v2.0"
    $ApiUrl = $ApiBaseUrl + $Endpoint

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
    
    Return $Request
}

########## End Internal Functions ##########

#Tenant level/general cmdlets
function Connect-BusinessCentralApi{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
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

function Get-BusinessCentralEnvironments{
    #This cmdlet doesn't use InvokeModuleApi since it uses the admin API instead of the normal/application API
    #Get a list of environments using the admin center API
    $environmentsApiUrl = "https://api.businesscentral.dynamics.com/admin/v2.21/applications/environments"
    $environments = (Invoke-WebRequest -Uri $environmentsApiUrl -Method GET -Headers $headers).content | Convertfrom-Json

    Return $environments.value
}

function Set-BusinessCentralEnvironmentContext{
    #This cmdlet is used since Business Central can have multiple environments, e.g. for production and sandbox
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )

    $env:BusinessCentralApiEnvironmentContext = $EnvironmentName
    Write-Host -ForegroundColor Green "Set Business Central API Environment to $EnvironmentName"
}

#Object level cmdlets
function Get-BusinessCentralCompany{

    $CompanyEndpoint = "/companies"

    $Companies = InvokeModuleApi -Endpoint $CompanyEndpoint

    Return $Companies.value
}

function Get-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
    )

    $CustomerEndpoint = "/companies($CompanyId)/customers"

    $Customers = InvokeModuleApi -Endpoint $CustomerEndpoint

    Return $Customers.value
}

function New-BusinessCentralCustomer{
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId,
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
        [ValidateSet('[A-Z][A-Z]')]
        [string]$State,
        [ValidateSet('[A-Z][A-Z]')]
        [string]$Country,
        [string]$PostalCode,
        [string]$PhoneNumber,
        [string]$Email,
        [string]$Website,
        [string]$salespersonCode
    )

    #Dynamically create a hashtable with whatever attributes were specified. Have to do this since you can't have a null key value in hashtables and you may not use all params when creating a new object
    #e.g. if you only specify a phone number and no country code, this will only add the phone number to the values passed in the body of the API call
    $Attributes = @{}
    $Params = $PSBoundParameters
    $Keys = $PsBoundParameters.Keys
    foreach ($Key in $Keys){
        #have to exclude the company ID since that isn't an attribute of the customer object
        if($Params.$Key -ne "=" -and $Key -ne "CompanyId"){
            $Attributes.Add($Key,$Params.$Key)
        }
    }

    $Body = $Attributes | ConvertTo-Json

    $CustomerEndpoint = "/companies($CompanyId)/customer"

    $Request = InvokeModuleApi -Endpoint $CustomerEndpoint -Method Post -Body $Body

    Return $Request
}

function Get-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId,
        [Parameter(Mandatory = $false)]
        [string]$ContactId
    )

    If(-not $ContactId){
        $ContactEndpoint = "/companies($CompanyId)/contacts"
    }
    else{
        $ContactEndpoint = "/companies/$CompanyId/contacts/$ContactId"
    }

    $Request = InvokeModuleApi -Endpoint $ContactEndpoint

    Return $Request.value
}

function New-BusinessCentralContact{
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        #Optional fields below here
        [string]$AddressLine1,
        [string]$AddressLine2,
        [string]$City,
        [string]$State,
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
        #have to exclude the company ID since that isn't an attribute of the customer object
        if($Params.$Key -ne "=" -and $Key -ne "CompanyId"){
            $Attributes.Add($Key,$Params.$Key)
        }
    }

    $Body = $Attributes | ConvertTo-Json

    $CustomerEndpoint = "/companies($CompanyId)/contacts"

    $Request = InvokeModuleApi -Endpoint $CustomerEndpoint -Method Post -Body $Body

    Return $Request
}
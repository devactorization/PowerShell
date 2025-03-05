<#
Written by Don Morgan
This module exposes the Business Central API via native PowerShell
#>

########## Begin Internal functions ##########
function GetOauthToken{
    <#
    .SYNOPSIS
        Gets an Oauth token using an app registration (client Id, tenant Id, client secret).
    .DESCRIPTION
        Business Central requires the use of Oauth and deprecated basic auth (i.e. API keys/tokens).
    .NOTES
        The access token has a 1h lifetime by default per Entra Id settings.
    .LINK
        Docs on getting an auth token using an app secret: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#first-case-access-token-request-with-a-shared-secret
        Business Central API: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/automation-apis-using-s2s-authentication
        More API docs: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/    
    #>
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
    <#
    .SYNOPSIS
        This is the main internal function for this module. It handles making the API calls to a given endpoint, authentication (once connected), etc.
    #>
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

#Debugging command
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
########## End Internal Functions ##########

#Tenant level/general cmdlets
function Connect-BusinessCentralApi{
    <#
    .SYNOPSIS
        Connects to Business Central via app registration.
    .NOTES
        Once connected, you will need to set an environment and company context via "Set-BusinessCentralEnvironmentContext" and "Set-BusinessCentralCompanyContext" before using other cmdlets.
    .EXAMPLE
        $clientId = "e32b5db8-a84e-4af2-8bb8-e434382a962d"
        $secret = "blahblahblahsomesecretblahblah~"
        $tenantId = "dd80a757-da1b-442a-a25f-199d5fee6a9e"
        Connect-BusinessCentralApi -ClientSecret $secret -ClientId $clientId -TenantId $tenantId
    #>
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
    <#
    .SYNOPSIS
        Gets Business Central environments.
    .DESCRIPTION
        Gets environments, e.g. production and sandbox environments.
        Also can be used to get the currently set environment context.
    .NOTES
        This cmdlet doesn't use InvokeBusinessCentralApi since it uses the admin API instead of the normal/application API.
    .EXAMPLE
        Get-BusinessCentralEnvironmentContext
    #>
    param(
        [switch]$Current
    )

    #Get currently set environment
    if($Current){
        return $env:BusinessCentralApiEnvironmentContext
    }
    #List all environments
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
    <#
    .SYNOPSIS
        Sets the environment that further cmdlets should be executed in.
    .DESCRIPTION
        The URI for a given API endpoint includes the environment (e.g. production or sandbox), this cmdlet sets an environment variable that is used by InvokeBusinessCentralApi in subsequent cmdlets so you don't need to specify the environment with each API call.
    .EXAMPLE
        Set-BusinessCentralEnvironmentContext -EnvironmentName "Contoso-Production"
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-admin-center-environments
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-environment-topology
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )

    $env:BusinessCentralApiEnvironmentContext = $EnvironmentName
    Write-Host -ForegroundColor Green "Set Business Central API environment context to $EnvironmentName"
}
function Set-BusinessCentralCompanyContext{
    <#
    .SYNOPSIS
        Sets the Business Central company that further cmdlets should be executed in.
    .DESCRIPTION
        The URI for a given API endpoint includes the company, this cmdlet sets an environment variable that is used by InvokeBusinessCentralApi in subsequent cmdlets so you don't need to specify the company with each API call.
    .EXAMPLE
        $Company = Get-BusinessCentralCompany | Where-Object{$_.name -eq "My Company"}
        Set-BusinessCentralCompanyContext -CompanyId $Company.id
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/about-new-company
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-environment-topology
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
    )

    $env:BusinessCentralApiCompanyContext = $CompanyId
    Write-Host -ForegroundColor Green "Set Business Central API company context to $CompanyId"
}

#Object level cmdlets
function Get-BusinessCentralCompany{
    <#
    .SYNOPSIS
        Gets companies in a Business Central environment
    .EXAMPLE
        Get-BusinessCentralCompany
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_company
    #>
    $CompanyEndpoint = "/companies"

    $Companies = InvokeBusinessCentralApi -Endpoint $CompanyEndpoint -NoCompanyContext

    Return $Companies.value
}
function Get-BusinessCentralCustomer{
    <#
    .SYNOPSIS
        Gets customer records, or a specific customer by Id.
    .EXAMPLE
        #Get specific customer
        Get-BusinessCentralCustomer -Id 12345678
        #Get all customers
        Get-BusinessCentralCustomer
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_get
    #>
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
function New-BusinessCentralCustomer{
    <#
    .SYNOPSIS
        Creates a new Business Central customer record with the given properties.
    .NOTES
        Returns the customer object that was created.
    .EXAMPLE
        $NewCustomerSplat = @{
            Display = "Fabrikam LTd"
            Number = "12345678""
            Type = "Company"
            AddressLine1 = "4321 Somewhere Lane"
            AddressLine2 = "Suite 1"
            City = "Schenectady"
            State = "New York"
            Country = "US"
            PostalCode = "12345"
        }
        $NewCustomer = New-BusinessCentralCustomer @NewCustomerSplat
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_create
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Company","Person")]
        [string]$Type,
        #Optional fields below here
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
function Remove-BusinessCentralCustomer{
    <#
    .SYNOPSIS
        Deletes a Business Central customer record.
    .NOTES
        Does not delete the associated company-type contact record.
    .EXAMPLE
        Remove-BusinessCentralCustomer -Id 12345678
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_delete
    #>
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
function Set-BusinessCentralCustomer{
    <#
    .SYNOPSIS
        Updates a Business Central customer record.
    .DESCRIPTION
        Updates a Business Central customer record. Supports updating single or multiple properties at once.
    .EXAMPLE
        Set-BusinessCentralCustomer -Id 12345678 -DisplayName "New Name"
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_update
    #>
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
function Get-BusinessCentralContact{
    <#
    .SYNOPSIS
        Gets Business Central contacts.
    .EXAMPLE
        #Get all contacts    
        Get-BusinessCentralContact

        #Get specific contact by Id
        Get-BusinessCentralContact -Id 12345678
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_get
    #>
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
function New-BusinessCentralContact{
    <#
    .SYNOPSIS
        Creates a new Business Central contact with the given properties.
    .EXAMPLE
        $NewContactSplat = @{
        DisplayName = "Jane Doe"
        Number = "12345678"
        AddressLine1 = "4321 Somewhere Lane"
        AddressLine2 = "Suite 1"
        City = "NYC"
        State = "New York"
        Country = "US"
        PostalCode = "12345"
        MobilePhoneNumber = "800-555-1212"
        Type = "Person"
        CompanyNumber = "87654321"
    }
    $NewContact = New-BusinessCentralContact @NewContactSplat
    .NOTES
        To create a contact associated with a customer (company) using the CompanyNumber property, you must resolve the customer contact number using Get-BusinessCentralContactRelation
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_create
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        #Optional fields below here
        [string]$Number,
        [string]$JobTitle,
        [string]$CompanyNumber,
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
        [string]$MobilePhoneNumber,
        [string]$Email
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
function Remove-BusinessCentralContact{
    <#
    .SYNOPSIS
        Deletes a contact from Business Central.
    .NOTES
        If you delete the company contact (with type: company) for a customer, it will also delete all related person contacts, but not the customer record.
    .EXAMPLE
        Remove-BusinessCentralContact -Id 12345678
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_delete
    #>
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
function Set-BusinessCentralContact{
    <#
    .SYNOPSIS
        Updates a contact in Business Central.
    .EXAMPLE
        Set-BusinessCentralContact -Id 12345678 -CompanyNumber 1029384756
        Set-BusinessCentralContact -Id 12345678 -CompanyNumber $ContactRelations.contactNumber
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_contact_update
        https://learn.microsoft.com/en-us/dynamics365/business-central/application/base-application/enum/microsoft.crm.businessrelation.contact-business-relation-link-to-table#values
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        #Optional fields below here
        [string]$DisplayName,
        [string]$JobTitle,
        [ValidateSet("Company","Person")]
        [string]$Type,
        [string]$CompanyNumber,
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
        [string]$MobilePhoneNumber,
        [string]$Email
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

function Get-BusinessCentralContactRelation{
    <#
    .SYNOPSIS
        Gets contacts related to a given vendor/customer.
    .EXAMPLE
        Get-BusinessCentralContactRelation -CustomerId 12345678
    .NOTES
        When relating person contacts with a company contact, you can use "Get-BusinessCentralContactRelation -CustomerId 12345678 | where-object{$_.contacttype -eq "company"}"
    .LINK
        https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_contactinformation
    #>
    param(
        [parameter(Mandatory = $true,ParameterSetName = "VendorRelation")]
        [string]$VendorId,
        [parameter(Mandatory = $true,ParameterSetName = "CustomerRelation")]
        [string]$CustomerId
    )

    switch($PsCmdlet.ParameterSetName){
        "VendorRelation" {
            $Endpoint = "/vendors($VendorId)/contactsInformation"
        }
        "CustomerRelation" {
            $Endpoint = "/customers($CustomerId)/contactsInformation"
        }
    }

    $Request = InvokeBusinessCentralApi -Endpoint $Endpoint

    Return $Request.value
}
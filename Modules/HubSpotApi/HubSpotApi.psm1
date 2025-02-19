<#
Written by Don Morgan
This module allows interacting with HubSpot's API via native PowerShell cmdlets/objects

Note: this is written to use the v3 HubSpot API
#>

########## Begin Internal functions ##########
function InvokeHubSpotApi {
    param(
        [Parameter(Mandatory = $true)]
        [validatePattern('/.*')] #Require the endpoint start with a slash, e.g. '/account-info/v3/details'
        [string]$Endpoint,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Get","Post","Delete")]
        [string]$Method = "get",
        [Parameter(Mandatory = $false)]
        $Body
    )

    if($Env:HubSpotApiVerbosity){
        Write-Host "Invoking API call with endpoint: $Endpoint" -ForegroundColor Yellow
    }

    #Make sure the ENV is already set for the API token and auth headers
    if($null -eq $Env:HubSpotApiKey -or $null -eq $env:HubSpotApiUrl){
        throw 'please run the "Connect-HubSpotApi" cmdlet first'
    }

    $ApiKey =  $Env:HubSpotApiKey
    $BaseUri =  $Env:HubSpotApiUrl

    $Uri = $BaseUri + $Endpoint

    $Headers = @{
        "Content-Type" = "application/json"
        "accept" = "application/json"
        "Authorization" = "Bearer $ApiKey"
    }

    #We'll see if pagination with a body for any method turns up any bugs lol
    if($Body){
        if($Env:HubSpotApiVerbosity){
            $BodyString = $Body.ToString()
            Write-Host "API query body: `n $BodyString" -ForegroundColor Yellow
        }

        $response = Invoke-RestMethod $Uri -Method $Method -Headers $Headers -Body $Body
        
        if($response.paging.next.link){
            if($Env:HubSpotApiVerbosity){
                Write-Host "API query result has pagination" -ForegroundColor Yellow
            }

            $result = $response.results

            while($response.paging.next.link){
                $nextPageUri = $response.paging.next.link
                $response = Invoke-RestMethod $nextPageUri -Method $Method -Headers $Headers -Body $Body
                $result += $response.results
            }
        }
        else{
            $result = $response
        }
    }
    else{
        $response = Invoke-RestMethod $Uri -Method $Method -Headers $Headers

        if($response.paging.next.link){
            if($Env:HubSpotApiVerbosity){
                Write-Host "API query result has pagination" -ForegroundColor Yellow
            }

            $result = $response.results

            while($response.paging.next.link){
                $nextPageUri = $response.paging.next.link
                $response = Invoke-RestMethod $nextPageUri -Method $Method -Headers $Headers
                $result += $response.results
            }
        }
        else{
            $result = $response
        }
    }
    
    return $result
}
########## End Internal Functions ##########
function Connect-HubSpotApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    $BaseApiUrl = "https://api.hubapi.com"

    #Build headers with auth token and content type
    $Headers = @{
        "Content-Type" = "application/json"
        "accept" = "application/json"
        "Authorization" = "Bearer $ApiKey"
    }

    #Using this API endpoint to test the connection
    $AccountEndpoint = "/account-info/v3/details"

    $Uri = $BaseApiUrl + $AccountEndpoint
    $response = Invoke-RestMethod $Uri -Method Get -Headers $Headers

    $AccountNumber = $response.portalId

    if($null -ne $AccountNumber){
        #Set environment variables for reuse in other cmdlets
        $Env:HubSpotApiKey = $ApiKey
        $Env:HubSpotApiUrl = $BaseApiUrl
        Write-Host -ForegroundColor Green "Connected to account id $AccountNumber"
    }
}

#Used for debugging
function Set-HubSpotApiVerbosity {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("None","Verbose","11")]
        $VerboseLevel
    )

    if($VerboseLevel -eq "Verbose"){
        $Env:HubSpotApiVerbosity = "Verbose"
    }
    elseif($VerboseLevel -eq "11"){
        $Env:HubSpotApiVerbosity = "Verbose"
        $VerbosePreference = 'Continue'
    }
    else{
        $Env:HubSpotApiVerbosity = $null
        $VerbosePreference = 'SilentlyContinue'
    }
}

#https://developers.hubspot.com/docs/guides/api/crm/pipelines
function Get-HubSpotPipeline {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Deal")]
        [string]$Type
    )

    $Endpoint = "/crm/v3/pipelines/$Type"

    $Req = InvokeHubSpotApi -Endpoint $Endpoint
    Return $Req.results  
}

#https://developers.hubspot.com/docs/guides/api/crm/pipelines#delete-a-pipeline
function Remove-HubSpotPipeline {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Deal")]
        [string]$Type,
        [Parameter(Mandatory = $true)]
        [string]$Id,
        #Force deletion doesn't check if there are records in the pipeline before deleting, use with caution
        [Parameter(Mandatory = $false)]
        [switch]$ForceDelete
    )

    $Endpoint = "/crm/v3/pipelines/$Type/$Id"

    if($ForceDelete){
        $Endpoint += "?validateReferencesBeforeDelete=false"
        Write-Host -ForegroundColor Yellow "Caution: this parameter may leave orphaned objects"
    }
    else{
        $Endpoint += "?validateReferencesBeforeDelete=true"
    }

    $Req = InvokeHubSpotApi -Endpoint $Endpoint -Method Delete
    Return $Req
}

#https://developers.hubspot.com/docs/guides/api/crm/objects/deals
function Get-HubSpotDeal {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$Properties = $null
    )

    $Endpoint = "/crm/v3/objects/deals"

    if($Id){
        $Endpoint += "/$Id"
    }
    if($Properties){
        $Endpoint += "?properties=$Properties"
    }

    $Req = InvokeHubSpotApi -Endpoint $Endpoint
    Return $Req
    
}

#https://developers.hubspot.com/docs/guides/api/crm/objects/deals#create-deals
function New-HubSpotDeal {
    param(
        [Parameter(Mandatory = $true)]
        [object]$PropertiesObject
    )

    $Endpoint = "/crm/v3/objects/deals"

    $Req = InvokeHubSpotApi -Endpoint $Endpoint -Body $Properties -Method Post
    Return $Req
}

#https://developers.hubspot.com/docs/guides/api/crm/using-object-apis#retrieve-records
function Get-HubSpotProperty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Object,
        [Parameter(Mandatory = $false)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    if($Name){
        $Endpoint = "/crm/v3/properties/$Object/$Name"
    }
    else{
        $Endpoint = "/crm/v3/properties/$Object"
    } 

    #https://developers.hubspot.com/docs/reference/api/crm/sensitive-data#manage-sensitive-data
    if($Sensitive){
        $Endpoint += "?dataSensitivity=sensitive"
    }
    
    $Req = InvokeHubSpotApi -Endpoint $Endpoint
    Return $Req.results
}

#https://developers.hubspot.com/docs/guides/api/crm/objects/companies
function Get-HubSpotCompany {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Id,
        [Parameter(Mandatory = $False)]
        [switch]$All,
        [Parameter(Mandatory = $false)]
        [string]$Properties = $null
    )

    $Endpoint = "/crm/v3/objects/companies"

    if($Id){
        $Endpoint += "/$Id"
    }
    if($Properties){
        $Endpoint += "?properties=$Properties"
    }

    $Req = InvokeHubSpotApi -Endpoint $Endpoint

    Return $Req
}

#Note: this cmdlet uses the v3 API and as such does not show secondary company associations (e.g. if there are two companies associated with one deal this cmdlet only returns the primary association)
#https://developers.hubspot.com/beta-docs/reference/api/crm/associations/association-details/v3
function Get-HubSpotAssociation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelatedObject,
        [Parameter(Mandatory = $true)]
        [string]$BaseObject,
        [Parameter(Mandatory = $false)]
        [string]$BaseObjectId,
        [Parameter(Mandatory = $false)]
        [switch]$Types
    )

    $BaseEndpoint = "/crm/v3/associations/"
    $AssociationEndpoint = $BaseEndpoint + $BaseObject + '/' + $RelatedObject

    if($Types){
        $Endpoint = $AssociationEndpoint + '/types'
        
        $Req = InvokeHubSpotApi -Endpoint $Endpoint
    }
    else{
        $Endpoint = $AssociationEndpoint + '/batch/read'
        
        $Body = @{
            inputs=@(
                @{
                    id = $BaseObjectId
                }
            )
        } | ConvertTo-Json

        $Req = InvokeHubSpotApi -Endpoint $Endpoint -Body $Body -Method Post
    }

    Return $Req.results
}

#https://developers.hubspot.com/docs/guides/api/crm/associations/associations-v3#create-associations
function New-HubSpotAssociation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseObject,
        [Parameter(Mandatory = $true)]
        [string]$BaseObjectId,
        [Parameter(Mandatory = $true)]
        [string]$RelatedObject,
        [Parameter(Mandatory = $true)]
        [string]$RelatedObjectId,
        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    $Endpoint = "/crm/v3/associations/" + $BaseObject + '/' + $RelatedObject + '/batch/create'

    $Body = @{
        inputs=@(
            @{
                from = @{
                    id = $BaseObjectId
                }
                
                to = @{
                    id = $RelatedObjectId
                }

                type = $Type
            }
        )
    } | ConvertTo-Json -Depth 10

    
    $Req = InvokeHubSpotApi -Endpoint $Endpoint -Body $Body -Method Post
    
    Return $Req
}

#https://developers.hubspot.com/docs/guides/api/crm/associations/associations-v3#remove-associations
function Remove-HubSpotAssociation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseObject,
        [Parameter(Mandatory = $true)]
        [string]$BaseObjectId,
        [Parameter(Mandatory = $true)]
        [string]$RelatedObject,
        [Parameter(Mandatory = $true)]
        [string]$RelatedObjectId,
        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    $Endpoint = "/crm/v3/associations/" + $BaseObject + '/' + $RelatedObject + '/batch/archive'

    $Body = @{
        inputs=@(
            @{
                from = @{
                    id = $BaseObjectId
                }
                
                to = @{
                    id = $RelatedObjectId
                }

                type = $Type
            }
        )
    } | ConvertTo-Json -Depth 10

    
    $Req = InvokeHubSpotApi -Endpoint $Endpoint -Body $Body -Method Post
    
    Return $Req
}

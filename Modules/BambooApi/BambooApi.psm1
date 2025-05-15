
########## Begin Internal functions ##########
function InvokeBambooApi {
    param(
        [Parameter(Mandatory = $true)]
        [validatePattern('/.*')] #Require the endpoint start with a slash, e.g. '/account-info/v3/details'
        [string]$Endpoint,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Get","Post")]
        [string]$Method = "get",
        [Parameter(Mandatory = $false)]
        $Body
    )

    $CompanyDomain = "engagestar"
    $BaseApiUrl = "https://api.bamboohr.com/api/gateway.php/$CompanyDomain/v1"

    #Make sure the ENV is already set for the API token and auth headers
    if($null -eq $Env:BambooApiKey){
        throw 'please run the "Connect-BambooApi" cmdlet first'
    }

    $ApiKey =  $Env:BambooApiKey

    $Uri = $BaseApiUrl + $Endpoint

    $Headers = @{
        "Content-Type" = "application/json"
        "accept" = "application/json"
        "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($ApiKey):x")))"

    }

    if($Body){
        $response = Invoke-RestMethod $Uri -Method $Method -Headers $Headers -body $Body
    }
    else{
        $response = Invoke-RestMethod $Uri -Method $Method -Headers $Headers
    }

    return $response
}

function FormatFieldBody {
    <#
    .SYNOPSIS
        Internal function that formats an array of field names for use in API call bodies.
    .DESCRIPTION
        Formats an array into another array with the elements double quoted.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Fields
    )

    $NewArray = @()
    Foreach ($Field in $Fields){
        $Value = '"' + $Field + '"'
        $NewArray += $Value
    }
    
    $JoinedArray = $NewArray -join ","
    
    Return $JoinedArray 
}

########## End Internal Functions ##########
function Connect-BambooApi {
    <#
    .SYNOPSIS
        Connects to the Bamboo HR API.
    .DESCRIPTION
        Sets the environment variable used for subsequent API calls.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    $Env:BambooApiKey = $ApiKey

    #Using this API endpoint to test the connection
    $CompanyInfoEndpoint = "/company_information"

    $Req = InvokeBambooApi -Endpoint $CompanyInfoEndpoint

    if($Req.displayName){
        $CompanyName = $Req.displayName
        Write-Host "Connected to $CompanyName"
    }
    else{
        Write-Error "Failed to connect to Bamboo API"
    }
}

function Get-BambooEmployeeFields {
    <#
    .SYNOPSIS
        Utility function for enumerating the available fields for employees.
    .LINK
        https://documentation.bamboohr.com/reference/metadata-get-a-list-of-fields
    #>
    $EmployeeFieldsEndpoint = "/meta/fields"
    $Req = InvokeBambooApi -Endpoint $EmployeeFieldsEndpoint
    Return $Req
}

function Get-BambooEmployee {
    <#
    .SYNOPSIS
        Gets employee directory. Not recommended, instead use Get-BambooDataset.
    .NOTES
        Not implementing per-employee invocation (by eeid) at this time
    .LINK
        https://documentation.bamboohr.com/reference/get-employee-1
        https://documentation.bamboohr.com/reference/get-employees-directory
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$Id
        #[Parameter(Mandatory = $false)]
        #[array]$Fields
    )

    if($Id){
        $EmployeeEndpoint = "/employees/$Id"
        $Req = InvokeBambooApi -Endpoint $EmployeeEndpoint
        Return $Req
    }
    else{
        $EmployeeDirectoryEndpoint = "/employees/directory"
        $Req = InvokeBambooApi -Endpoint $EmployeeDirectoryEndpoint
        Return $Req.employees
    }
}

function Get-BambooDatasetFields {
    <#
    .SYNOPSIS
        Utility function for enumerating the available fields for a given dataset.
    .NOTES
        use the name of the returned fields when calling Get-BambooDataset
    .LINK
        https://documentation.bamboohr.com/reference/get-fields-from-dataset-1
    #>
        param(
        [Parameter(Mandatory = $true)]
        [string]$DatasetName
    )

    $DatasetFieldsEndpoint = "/datasets/$DatasetName/fields"

    $Req = InvokeBambooApi -Endpoint $DatasetFieldsEndpoint
    Return $Req.fields
}

function Get-BambooDataset {
    <#
    .SYNOPSIS
        Gets a dataset from Bamboo with a list of given fields.
    .NOTES
        Datasets replaced reports for doing bulk employee queries.
        To get a list of datasets, refer to https://documentation.bamboohr.com/reference/getdatasets-1
    .LINK
        https://documentation.bamboohr.com/reference/get-data-from-dataset-1
        https://documentation.bamboohr.com/reference/getdatasets-1
    #>
        param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [array]$Fields
    )

    $DatasetEndpoint = "/datasets/$Name"

    $FieldString = FormatFieldBody -Fields $Fields
    $Body = "{`"fields`":[$FieldString]}"

    $Req = InvokeBambooApi -Endpoint $DatasetEndpoint -Method Post -Body $Body
    Return $Req.data
}



# Summary

This module allows for interacting with the HubSpot API (e.g. creating/listing/updating Deals) via native PowerShell cmdlets.

Please note that this module has limited functionality and does not implement all API functionality by design. It was designed with the intention of being able to automate basic CRUD operations for common objects.

# Authentication

Before you can use any other cmdlets, you need to run the 'Connect-HubSpotApi' cmdlet to authenticate to your instance.

```
Connect-HubSpotApi -ApiKey "SuperSecretToken"
```

Once authenticated, you can run other cmdlets.

# Examples

Below is several examples of how to use this module.

```
#Get a list of properties, useful for finding the internal name/id that must be included when querying for them

#Get all properties for Deals
$DealProperties = Get-HubSpotProperty -Object "Deals"

#Get all properties for Contacts
$ContactProperties = Get-HubSpotProperty -Object "Contacts"


#Specific properties to retrieve
$PropertiesArray =@(
        "hs_deal_stage_probability",
        "hs_forecast_probability",
        "hs_manual_forecast_category",
        "dealtype",
        "dealstage",
        "amount",
        "createDate",
        "closeDate",
        "hs_closed_won_date"
)
$Properties = $PropertiesArray -join ','

$DealWithProperties = Get-HubSpotDeal -Id "123456789" -Properties $Properties


#Get all deals
$AllDeals = Get-HubSpotDeal


#Get pipelines for a given object type
$DealPipelines = Get-HubSpotPipeline -Type Deal

#Get pipeline stages
$DealPipelines | Select-Object -ExpandProperty stages
#Get pipeline stage id
$StageId = ($DealPipelines | Select-Object -ExpandProperty stages | Where-Object{$_.displayOrder -eq 0}).id

#Create new deal with a given pipeline, stage, name
$Properties =@{
    properties = @{
    "pipeline" = $PipelineId
    "dealstage" = $StageId
    "dealname" = "Test Dealio"
    }
} | ConvertTo-Json
$NewDeal = New-HubSpotDeal -Properties $PropertiesObject


#Get all Companies
$AllCompanies = Get-HubSpotCompany -All

$SpecificCompany = Get-HubSpotCompany -Id "0987654321"

#Get all association types between companies and contacts
$CompanyAssociations = Get-HubSpotAssociation -BaseObject "Companies" -RelatedObject "Contacts" -Types 

#Get all associations between the test company and any contacts
$CompanyAssociationsWithContacts = Get-HubSpotAssociation -BaseObject "Companies" -RelatedObject "Contacts" -BaseObjectId $SpecificCompany.id


#Create new association
$BigSplat = @{
    BaseObject = "Deal"
    BaseObjectId = $TestDeal.id
    RelatedObject = "Company"
    RelatedObjectId = $TestCompany.id
    Type = "deal_to_company"
}

New-HubSpotAssociation @BigSplat

#Get all companies associated with a deal - note that the v3 API has a limitation and only shows the primary company/deal association
$LittleSplat = @{
    BaseObject = "Deal"
    BaseObjectId = $TestDeal.id
    RelatedObject = "Company"
}
$CompanyAssociationsWithTestDeal = Get-HubSpotAssociation @LittleSplat
$AssociatedCompanies = foreach ($Company in $CompanyAssociationsWithTestDeal.to){Get-HubSpotCompany -Id $Company.id}
$AssociatedCompanies.properties.name

#Remove association
Remove-HubSpotAssociation @BigSplat

```


# Debugging Commands

These commands can be used for debugging purposes:
```
#Set to normal verbosity, which writes API calls/URLs to console
Set-HubSpotApiVerbosity -VerboseLevel Verbose

#Module specific verbosity + $VerbosePreference = "continue"
Set-HubSpotApiVerbosity -VerboseLevel 11

#Disable verbose mode
Set-HubSpotApiVerbosity -VerboseLevel None
```


# License

See the "LICENSE.txt" file in the root of this repo.
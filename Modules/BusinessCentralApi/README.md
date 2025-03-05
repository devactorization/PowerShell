# Summary

This module allows for interacting with the Business Central REST API (e.g. creating/listing/updating Customer records) via native PowerShell cmdlets.

Please note that this module has limited functionality and does not implement all API functionality by design. It was designed with the intention of being able to automate basic CRUD operations for common objects.

# Authentication

Before you can use any other cmdlets, you need to run the ```Connect-BusinessCentralApi``` cmdlet to authenticate to your instance.

Once authenticated, you will need to set an environment and company context with ```Set-BusinessCentralEnvironmentContext``` and ```Set-BusinessCentralCompanyContext``` respectively. This is required due to the URIs of the API including the environment and company, e.g. ```https://api.businesscentral.dynamics.om/v2.0/<environment name>/api/v2.0/companies(<company Id>)/customers```


Once you are connected and have your contexts set, you can run other cmdlets.

**NOTE:** Microsoft requires the use of Oauth for the API, which means the API token obtained when running ```Connect-BusinessCentralApi``` is valid for one hour by default (based on Entra ID default settings).

# Examples

This module includes [Comment-based help](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-7.5)

To see examples and information about cmdlets, use ```Get-Help <cmdlet>```, for example ```Get-Help Get-BusinessCentralCustomer```

# License

See the [LICENSE.txt](https://github.com/mister-dj/PowerShell/blob/main/LICENSE.txt) file in the root of this repo.
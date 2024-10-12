# Summary
These templates are meant to be a quickstart framework for writing new PowerShell modules that act as API wrappers.

# Example Scenario
For example, Microsoft Dynamics 365 Business Central has a RESTful API, but no PowerShell modules for things like creating new contacts, customers, etc. (note: there are modules for on-prem Dynamics but not cloud). 

# Contents
1. RESTful API with Oauth - M365

    This template is for RESTful that are part of the Microsoft 365 ecosystem and use app registrations with OAuth for authentication (as opposed to simple API keys/tokens). It includes bootstrap functions for getting an auth token using a client ID+secret from an app registration. This template came about from my work with the Business Central API. 

2. RESTful API with Bearer Token Auth

    This template is for RESTful APIs which use standard bearer tokens for authentication. This template came about from my work with the Hubspot API.

3. GraphQL API with Bearer Token Auth

    This template is for GraphQL APIs that use bearer token auth. My condolences if you have to use this... I personally dislike GraphQL compared to REST, and found the API queries to be extremely painful to work with/generate in PowerShell. This template came about from my work with the Monday.com API.

# Background 
These templates are something I created after writing modules for APIs for several products I use/admin at work.

# Disclaimer
These templates are provided as-is and are NOT complete or final, they are meant to help save time when writing a new module by providing a framework which offers (I think good) code reusability, an effective design pattern and structure.

# Contribute
Please open a pull request if you'd like to contribute, but be aware that I don't currently *actively* watch for PRs and may or may not maintain this framework.
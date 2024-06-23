<#
This snippet is used for sending email using Microsoft Graph. It's a good replacement for send-mailmessage.

Note: this is meant to be ran as an Azure runbook with a managed identity. Sender address must be a valid user.

This is largely based on https://www.techguy.at/send-mail-with-attachment-powershell-and-microsoft-graph-api/

NOTE: the managed identity must be granted the Mail.Send permission
https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http#permissions
https://techcommunity.microsoft.com/t5/azure-integration-services-blog/grant-graph-api-permission-to-managed-identity-object/ba-p/2792127

#>


#Get auth token using managed identity
#https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity?tabs=portal%2Cpowershell#connect-to-azure-services-in-app-code
$resourceURI = "https://graph.microsoft.com"
$tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI

#Configure Mail Properties
$MailSender = "john@contoso.com"
$Attachment="$env:TEMP\test.txt"
$Recipient="jane@contoso.com"


#Get File Name and Base64 string
$FileName=(Get-Item -Path $Attachment).name
$base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attachment))

#Build headers
$headers = @{
    "Authorization" = "Bearer $($tokenResponse.access_token)"
    "Content-type"  = "application/json"
}

#Send Mail    
$URLsend = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
$BodyJsonSend = @"
{
    "message": {
      "subject": "Hello World from Microsoft Graph API",
      "body": {
        "contentType": "HTML",
        "content": "This Mail is sent via Microsoft <br> GRAPH <br> API<br> and an Attachment <br>"
      },
      
      "toRecipients": [
        {
          "emailAddress": {
            "address": "$Recipient"
          }
        }
      ]
      ,"attachments": [
        {
          "@odata.type": "#microsoft.graph.fileAttachment",
          "name": "$FileName",
          "contentType": "text/plain",
          "contentBytes": "$base64string"
        }
      ]
    },
    "saveToSentItems": "false"
  }
"@

Invoke-RestMethod -Method POST -Uri $URLsend -Headers $headers -Body $BodyJsonsend

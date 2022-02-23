# This example shows how to call the 'list' endpoint of the File API in order to retrieve all available files to be downloaded"

Write-Host "================================================"
Write-Host "File API example: Listing available files."
Write-Host "================================================"

#region User_configuration

Write-Host "Enter your application's client ID."
Write-Host "(it can be retrieved from your application in the Developer Portal, under the name Consumer Key)"
$clientId = Read-Host

Write-Host "Enter your application's client secret."
Write-Host "(it can be retrieved from your application in the Developer Portal, under the name Secret Key)"
$clientSecret = Read-Host

Write-Host "Enter your application's tenant."
Write-Host "(if your application is only allowed to one tenant (the most common scenario) you can leave this field empty by pressing Enter)"
$tenantId = Read-Host

#endregion

#region Internal_configuration

$authTokenApiBaseUrl = "https://api.raet.com/authentication"
$fileApiBaseUrl = "https://api.raet.com/mft/v1.0"

#endregion

#region Retrieve_authentication_token

Write-Host "Retrieving the authentication token..."

$authHeaders = @{
    "Content-Type"  = "application/x-www-form-urlencoded";
    "Cache-Control" = "no-cache";
}
$authBody = @{
    "grant_type"    = "client_credentials";
    "client_id"     = $clientId;
    "client_secret" = $clientSecret;
}

$authTokenResponse = Invoke-RestMethod -Method "Post" -Uri "$($authTokenApiBaseUrl)/token" -Headers $authHeaders -Body $authBody
$token = $authTokenResponse.access_token

Write-Host "Authentication token retrieved."

#endregion

#region List_files

Write-Host "Calling the 'list' endpoint..."

$listHeaders = @{
    "x-raet-tenant-id"  = $tenantId;
    "Authorization" = "Bearer $($token)";
}

$listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files?role=subscriber" -Headers $listHeaders

Write-Host "List of available files:"
Write-Host "------------------------------------------------"
$listResponse | ConvertTo-Json -Depth 10
Write-Host "------------------------------------------------"
Write-Host "Tip: In order to download a file, call the 'download' endpoint with the desired fileId shown in the list above."

#endregion

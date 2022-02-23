[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, HelpMessage = 'Client ID of your application. It can be retrieved from your application in the Developer Portal, under the name Consumer Key.')]
    [string] $clientId,

    [Parameter(Mandatory = $true, HelpMessage = 'Client secret of your application. It can be retrieved from your application in the Developer Portal, under the name Secret Key.')]
    [string] $clientSecret,

    [Parameter(Mandatory = $true, HelpMessage = 'Tenant ID of your application.')]
    [AllowEmptyString()]
    [string] $tenantId
)

Write-Host ================================================
Write-Host File API example: Listing available files.
Write-Host ================================================

# Internal configuration
$authTokenApiBaseUrl = "https://api.raet.com/authentication"
$fileApiBaseUrl = "https://api.raet.com/mft/v1.0"

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

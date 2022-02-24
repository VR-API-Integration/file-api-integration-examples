# This example shows how to call the 'list' endpoint of the File API with filters in order to retrieve the information of the specified files

Write-Host "================================================"
Write-Host "File API example: Listing filtered files."
Write-Host "================================================"

#region Configuration

$configPath = "C:\repositories\Ftaas\Ftaas.Examples\File API integration with CURL\PowerShell\config.xml"
[xml]$configDocument = Get-Content $configPath
$config = $configDocument.Configuration

$clientId = $config.Credentials.ApiKey
$clientSecret = $config.Credentials.SecretKey
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

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
    "x-raet-tenant-id" = $tenantId;
    "Authorization"    = "Bearer $($token)";
}
$listBody = @{
    '$filter' = $listFilter;
}

$listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files?role=subscriber" -Headers $listHeaders -Body $listBody

if ($listFilter) {
    Write-Host "List of files filtered by <$($listFilter)>:"
} else {
    Write-Host "List of files:"
}
Write-Host "------------------------------------------------"
$listResponse | ConvertTo-Json -Depth 10
Write-Host "------------------------------------------------"
Write-Host "Tip: In order to download a file, call the 'download' endpoint with the desired fileId shown in the list above."

#endregion

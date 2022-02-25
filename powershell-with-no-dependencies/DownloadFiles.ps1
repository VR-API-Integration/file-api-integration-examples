# This example shows how to call the 'list' endpoint of the File API with filters in order to retrieve the information of the specified files

Write-Host "================================================"
Write-Host "File API example: Download available files."
Write-Host "================================================"

#region Configuration

$configPath = "$($PSScriptRoot)\config.xml"
[xml]$configDocument = Get-Content $configPath
$config = $configDocument.Configuration

$clientId = $config.Credentials.ApiKey
$clientSecret = $config.Credentials.SecretKey
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path

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
    "role"    = $role
}

$listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files" -Headers $listHeaders -Body $listBody
$filesToDownload = @()
foreach ($fileData in $listResponse.data) {
    $filesToDownload += @{
        Id   = $fileData.fileId
        Name = $fileData.fileName
    }
}

Write-Host "List of files retrieved."

#endregion

#region Download_files

Write-Host "Calling the 'download' endpoint..."

$downloadHeaders = @{
    "x-raet-tenant-id" = $tenantId;
    "Authorization"    = "Bearer $($token)";
    "Accept"           = "application/octet-stream";
}
$downloadBody = @{
    "role" = $role;
}

foreach ($fileToDownload in $filesToDownload) {
    Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files/$($fileToDownload.Id)" -Headers $downloadHeaders -Body $downloadBody -OutFile "$($downloadPath)\$($fileToDownload.Name)"
    Write-Host "File <$($fileToDownload.Id)> with name <$($fileToDownload.Name)> was downloaded."
}

Write-Host "All files were downloaded. You can find them in $($downloadPath)"

#endregion

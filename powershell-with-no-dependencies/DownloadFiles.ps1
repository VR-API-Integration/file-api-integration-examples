# This example shows how to call the 'list' endpoint of the File API with filters in order to retrieve the information of the specified files

Write-Host "================================================"
Write-Host "File API example: Download available files."
Write-Host "================================================"

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

#region Configuration

# XXX
# $configPath = "$($PSScriptRoot)\config.xml"
$configPath = "C:\Users\AlbertoInf\Inbox\PBI FTaaS Improve curl examples\config.xml"
# XXX Ensure you can actually use the [xml] thing.
[xml]$configDocument = Get-Content $configPath
$config = $configDocument.Configuration

$clientId = $config.Credentials.ApiKey
$clientSecret = $config.Credentials.SecretKey
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames

$authTokenApiBaseUrl = "https://api.raet.com/authentication"
$fileApiBaseUrl = "https://api.raet.com/mft/v1.0"

#endregion

#region Retrieve_authentication_token

Write-Host "Retrieving the authentication token..."

# $authHeaders = @{
#     "Content-Type"  = "application/x-www-form-urlencoded";
#     "Cache-Control" = "no-cache";
# }
# $authBody = @{
#     "grant_type"    = "client_credentials";
#     "client_id"     = $clientId;
#     "client_secret" = $clientSecret;
# }

# $authTokenResponse = Invoke-RestMethod -Method "Post" -Uri "$($authTokenApiBaseUrl)/token" -Headers $authHeaders -Body $authBody
# $token = $authTokenResponse.access_token

# XXX
$token = $config.XXXToken

Write-Host "Authentication token retrieved."

#endregion

#region List_files

Write-Host "Calling the 'list' endpoint..."

# $listHeaders = @{
#     "x-raet-tenant-id" = $tenantId;
#     "Authorization"    = "Bearer $($token)";
# }
# $listBody = @{
#     '$filter' = $listFilter;
#     "role"    = $role
# }

# $listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files" -Headers $listHeaders -Body $listBody
# # $randomBinFiles = $content.links | where {$_.innerHTML -like 'random*'} | select href
# $filesToDownload = @()
# foreach ($fileData in $listResponse.data) {
#     $filesToDownload += @{
#         Id   = $fileData.fileId
#         Name = $fileData.fileName
#     }
# }

$filesToDownload = @(
    @{
        Id   = "c5d7438e-5c29-47e7-b518-01e5a39d6711"
        Name = "sandbox_test_file.txt"
    },
    @{
        Id   = "d92ffb21-7938-488b-a405-bcbc9e0a9696"
        Name = "sandbox_test_file.xml"
    }
)

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
    Write-Host "Downloading file <$($fileToDownload.Id)> with name <$($fileToDownload.Name)>."
    if (($ensureUniqueNames -eq $true) -and (Test-Path "$($downloadPath)\$($fileToDownload.Name)" -PathType Leaf)) {
        Write-Host "There is already a file with the same name in the specified path."
        Write-Host "Renaming the file to be downloaded."
        $fileNameWithoutExtension = Split-Path $fileToDownload.Name -LeafBase # XXX This shit doesn't work, create your own method.
        $fileExtension = Split-Path $fileToDownload.Name -Extension
        $timestamp = Get-Date -Format FileDateTimeUniversal
        $fileToDownload.Name = "$($fileNameWithoutExtension) - $($timestamp)$($fileExtension)"
        Write-Host "File has been renamed to <$($fileToDownload.Name)>."
    }

    Invoke-RestMethod `
        -Method "Get" `
        -Uri "$($fileApiBaseUrl)/files/$($fileToDownload.Id)" `
        -Headers $downloadHeaders  `
        -Body $downloadBody -OutFile "$($downloadPath)\$($fileToDownload.Name)"
        
    Write-Host "File <$($fileToDownload.Id)> with name <$($fileToDownload.Name)> was downloaded."
}

Write-Host "All files were downloaded. You can find them in $($downloadPath)"

#endregion

# This example shows how to download all the files specified in a filter

Write-Host "========================================================="
Write-Host "File API example: Download files specified in a filter."
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

#region Helpers

function Get-FileNameInfo_FileAPIHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName
    )

    $fileNameInfo = @{
        Name      = $fileName
        Extension = ""
    }
    
    $splitFileName = $fileName -split "\."
    if ($splitFileName.Length -gt 1) {
        $fileNameInfo.Name = $splitFileName[0..($splitFileName.Length - 2)] -Join "."
        $fileNameInfo.Extension = ".$($splitFileName[-1])"
    }

    return $fileNameInfo
}

function ConvertTo-UniqueName_FileAPIHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName
    )

    $fileNameInfo = Get-FileNameInfo_FileAPIHelper $fileName
    $fileNameWithoutExtension = $fileNameInfo.Name
    $fileExtension = $fileNameInfo.Extension
    $timestamp = Get-Date -Format FileDateTimeUniversal

    $uniqueFileName = "$($fileNameWithoutExtension) - $($timestamp)$($fileExtension)"
    return $uniqueFileName
}

class DownloadChunkManager {
    [long]$ChunkStart
    [long]$ChunkEnd

    hidden [string] $_fileApiBaseUrl
    hidden [string] $_fileId
    hidden [long] $_fileSize
    hidden [long] $_chunkSize
    hidden [string] $_fullDownloadPath
    hidden [string] $_role
    hidden [string] $_tenantId
    hidden [string] $_token

    hidden [long] $_byteReadCount
    hidden [PSCustomObject] $_downloadHeaders
    hidden [PSCustomObject] $_downloadBody

    DownloadChunkManager(
        [string] $fileApiBaseUrl,
        [string] $fileId,
        [long] $fileSize,
        [long] $chunkSize,
        [string] $fullDownloadPath,
        [string] $role,
        [string] $tenantId,
        [string] $token
    ) {
        $this._fileApiBaseUrl = $fileApiBaseUrl
        $this._fileId = $fileId
        $this._fileSize = $fileSize
        $this._chunkSize = $chunksize
        $this._fullDownloadPath = $fullDownloadPath
        $this._role = $role
        $this._tenantId = $tenantId
        $this._token = $token

        $this.RestartValues()
    }

    [void] NextChunk() {
        $this._downloadHeaders.Range = "bytes=$($this.ChunkStart)-$($this.ChunkEnd)"

        Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this._fileApiBaseUrl)/files/$($this._fileId)" `
            -Headers $this._downloadHeaders `
            -Body $this._downloadBody `
            -OutFile $this._fullDownloadPath

        $this.UpdateValues()
    }

    [bool] HasFinished() {
        return $this._byteReadCount -ge ($this._fileSize - 1)
    }

    [void] RestartValues() {
        $this.ChunkStart = 0
        $this.ChunkEnd = $this.ChunkStart + $this._chunkSize - 1

        $this._byteReadCount = 0
        $this._downloadHeaders = @{
            "x-raet-tenant-id" = $this._tenantId;
            "Authorization"    = "Bearer $($this._token)";
            "Accept"           = "application/octet-stream";
        }
        $this._downloadBody = @{
            "role" = $this._role;
        }
    }

    hidden [void] UpdateValues() {
        $this._byteReadCount += $this.ChunkEnd - $this.ChunkStart + 1
        $this.ChunkStart = $this.ChunkEnd + 1

        if (($this.ChunkEnd + $this._chunkSize) -ge $this._fileSize) {
            $this.ChunkEnd = $this._fileSize - 1
        }
        else {
            $this.ChunkEnd = $this.ChunkEnd + $this._chunkSize
        }
    }
}

#endregion

#region Program

#region Configuration

# XXX
# $configPath = "$($PSScriptRoot)\config.xml"
$configPath = "C:\Users\AlbertoInf\Inbox\PBI FTaaS Improve curl examples\config.xml"
[xml]$configDocument = Get-Content $configPath
$config = $configDocument.Configuration

$clientId = $config.Credentials.ApiKey
$clientSecret = $config.Credentials.SecretKey
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames
# $maxChunkSize = ([long]$config.Download.MaxChunkSizeMB) * 1024 * 1024
$maxChunkSize = 30 # XXX

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
#         Size = $fileData.fileSize
#     }
# }

$filesToDownload = @(
    @{
        Id   = "c5d7438e-5c29-47e7-b518-01e5a39d6711"
        Name = "sandbox_test_file.txt"
        Size = 33
    }
    # @{
    #     Id   = "d92ffb21-7938-488b-a405-bcbc9e0a9696"
    #     Name = "sandbox_test_file.xml"
    #     Size = 107
    # }
)

Write-Host "List of files retrieved."

#endregion

#region Download_files

Write-Host "Calling the 'download' endpoint..."

# $downloadHeaders = @{
#     "x-raet-tenant-id" = $tenantId;
#     "Authorization"    = "Bearer $($token)";
#     "Accept"           = "application/octet-stream";
# }
# $downloadBody = @{
#     "role" = $role;
# }

foreach ($fileToDownload in $filesToDownload) {
    Write-Host "Downloading file <$($fileToDownload.Id)> with name <$($fileToDownload.Name)>."

    if (($ensureUniqueNames -eq $true) -and (Test-Path "$($downloadPath)\$($fileToDownload.Name)" -PathType Leaf)) {
        Write-Host "There is already a file with the same name in the download path. Renaming the file to be downloaded..."
        $fileToDownload.Name = ConvertTo-UniqueName_FileAPIHelper $fileToDownload.Name
        Write-Host "File will be downloaded with name <$($fileToDownload.Name)>."
    }

    [DownloadChunkManager] $downloadChunkManager = [DownloadChunkManager]::new(
        $fileApiBaseUrl,
        $fileToDownload.Id,
        $fileToDownload.Size,
        $maxChunkSize,
        "$($downloadPath)\$($fileToDownload.Name)",
        $role,
        $tenantId,
        $token
    )

    while (!$downloadChunkManager.HasFinished()) {
        $downloadChunkManager.NextChunk()
    }

    # Invoke-RestMethod `
    #     -Method "Get" `
    #     -Uri "$($fileApiBaseUrl)/files/$($fileToDownload.Id)" `
    #     -Headers $downloadHeaders `
    #     -Body $downloadBody `
    #     -OutFile "$($downloadPath)\$($fileToDownload.Name)"
        
    Write-Host "File <$($fileToDownload.Id)> with name <$($fileToDownload.Name)> was downloaded."
}

Write-Host "All files were downloaded. You can find them in $($downloadPath)"

#endregion

#endregion

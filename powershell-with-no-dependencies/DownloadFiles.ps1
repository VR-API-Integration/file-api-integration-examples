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

class FileApiService {
    [string] $BaseUrl
    [int] $PageIndex
    [bool] $IsLastPage
    
    hidden [int] $_pageSize
    hidden [int] $_totalFilesAmount
    hidden [PSCustomObject] $_defaultHeaders
    hidden [string] $_listFilter
    hidden [string] $_role

    FileApiService (
        [string] $baseUrl,
        [string] $role,
        [string] $tenantId,
        [string] $token,
        [string] $listFilter
    ) {
        $this.BaseUrl = $baseUrl
        $this.PageIndex = 0
        $this.IsLastPage = $false

        $this._role = $role
        $this._pageSize = 20
        $this._listFilter = $listFilter
        $this._defaultHeaders = @{
            "x-raet-tenant-id" = $tenantId;
            "Authorization"    = "Bearer $($token)";
        }
    }

    [PSCustomObject] NextListPage() {
        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files?role=$($this._role)&pageIndex=$($this.PageIndex)&pageSize=$($this._pageSize)&`$filter=$($this._listFilter)&`$orderBy=uploadDate asc" `
            -Headers $this._defaultHeaders `
        
        $files = @()
        foreach ($fileData in $response.data) {
            $files += @{
                Id   = $fileData.fileId
                Name = $fileData.fileName
                Size = $fileData.fileSize
            }
        }

        $this._totalFilesAmount = $response.count
        $this.IsLastPage = $this._pageSize * ($this.PageIndex + 1) -ge $this._totalFilesAmount
        
        $this.PageIndex++
        return $files
    }

    [void] DownloadFile([PSCustomObject] $fileInfo, [string] $downloadPath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($this._role)" `
            -Headers $headers `
            -OutFile "$($downloadPath)\$($fileInfo.Name)"
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

$clientId = $config.Credentials.ClientId
$clientSecret = $config.Credentials.ClientSecret
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames
$maxChunkSize = ([long]$config.Download.MaxChunkSizeMB) * 1024 * 1024
# $maxChunkSize = 30 # XXX

# $authTokenApiBaseUrl = "https://api.raet.com/authentication"
# $fileApiBaseUrl = "https://api.raet.com/mft/v1.0"
# $authTokenApiBaseUrl = "https://api-test.raet.com/authentication"
$fileApiBaseUrl = "https://api-test.raet.com/mft/v1.0"

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

Write-Host "Calling the 'list' endpoint..."

[FileApiService] $fileApiService = [FileApiService]::new(
    $fileApiBaseUrl,
    $role,
    $tenantId,
    $token,
    $listFilter
)

Write-Host "List of files retrieved."

Write-Host "Calling the 'download' endpoint..."

while (-not $fileApiService.IsLastPage) {
    $filesInfo = $fileApiService.NextListPage()

    foreach ($fileInfo in $filesInfo) {
        Write-Host "Downloading file <$($fileInfo.Id)> with name <$($fileInfo.Name)>."

        if (($ensureUniqueNames -eq $true) -and (Test-Path "$($downloadPath)\$($fileInfo.Name)" -PathType Leaf)) {
            Write-Host "There is already a file with the same name in the download path. Renaming the file to be downloaded..."
            $fileInfo.Name = ConvertTo-UniqueName_FileAPIHelper $fileInfo.Name
            Write-Host "File will be downloaded with name <$($fileInfo.Name)>."
        }

        $fileApiService.DownloadFile($fileInfo, $downloadPath)
        
        Write-Host "File <$($fileInfo.Id)> with name <$($fileInfo.Name)> was downloaded."
    }

    Write-Host "All files were downloaded. You can find them in $($downloadPath)"
}

#endregion

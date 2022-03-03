# This example shows how to download all the files specified in a filter.

Write-Host "========================================================="
Write-Host "File API example: Download files specified in a filter."
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

#region Configuration

# XXX
# $configPath = "$($PSScriptRoot)\config.xml"
$configPath = "C:\Users\AlbertoInf\Inbox\PBI FTaaS Improve curl examples\config.xml"
$configDocument = [xml](Get-Content $configPath)
$config = $configDocument.Configuration

$clientId = $config.Credentials.ClientId
$clientSecret = $config.Credentials.ClientSecret
$tenantId = $config.TenantId
$filter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames

# $authTokenApiBaseUrl = "https://api.raet.com/authentication"
# $fileApiBaseUrl = "https://api.raet.com/mft/v1.0"
$authTokenApiBaseUrl = "https://api-test.raet.com/authentication"
$fileApiBaseUrl = "https://api-test.raet.com/mft/v1.0"

#endregion Configuration

#region Retrieve_authentication_token

Write-Host "----"
Write-Host "Retrieving the authentication token..."

# [AuthenticationApiService] $authenticationApiService = [AuthenticationApiService]::new($authTokenApiBaseUrl)
# $token = $authenticationApiService.NewToken($clientId, $clientSecret)

# XXX
$token = $config.XXXToken

Write-Host "Authentication token retrieved."

#endregion Retrieve_authentication_token

#region List

Write-Host "----"
Write-Host "Retrieving the files that fulfill the filter <$($filter)>..."

[FileApiService] $fileApiService = [FileApiService]::new(
    $fileApiBaseUrl,
    $tenantId,
    $token
)

$pageIndex = 0
$pageSize = 20
$isLastPage = $false
$filesInfo = @()
do {
    $listResponse = $fileApiService.ListFiles($role, $pageIndex, $pageSize, $filter)

    foreach ($fileData in $listResponse.data) {
        $filesInfo += @{
            Id   = $fileData.fileId
            Name = $fileData.fileName
            Size = $fileData.fileSize
        }
    }

    $isLastPage = $pageSize * ($pageIndex + 1) -ge $listResponse.count
    $pageIndex++
} while (-not $isLastPage)

Write-Host "$($filesInfo.Count) files retrieved."

#endregion List

#region Download

$downloadedFilesCount = 0
foreach ($fileInfo in $filesInfo) {
    Write-Host "----"
    Write-Host "Downloading file $($downloadedFilesCount + 1)/$($filesInfo.Count)."
    Write-Host "| ID: $($fileInfo.Id)"
    Write-Host "| Name: $($fileInfo.Name)"

    if (($ensureUniqueNames -eq $true) -and (Test-Path "$($downloadPath)\$($fileInfo.Name)" -PathType Leaf)) {
        Write-Host "There is already a file with the same name in the download path."

        # $fileInfo.Name = ConvertTo-UniqueName_FileAPIHelper $fileInfo.Name
        $fileInfo.Name = [FileNameHelper]::ConverToUnique($fileInfo.Name) # XXX Not working.

        Write-Host "| New name: $($fileInfo.Name)"
    }

    $fileApiService.DownloadFile($role, $fileInfo, $downloadPath)
    $downloadedFilesCount++
        
    Write-Host "The file was downloaded."
}

Write-Host "----"
Write-Host "All files were downloaded."
Write-Host "| Path: $($downloadPath)"

#endregion Download

# -------- END OF THE PROGRAM --------
# Bellow there are classes to help the readability of the program

#region Classes

class FileApiService {
    [string] $BaseUrl
    
    hidden [PSCustomObject] $_defaultHeaders

    FileApiService (
        [string] $baseUrl,
        [string] $tenantId,
        [string] $token
    ) {
        $this.BaseUrl = $baseUrl
        $this._defaultHeaders = @{
            "x-raet-tenant-id" = $tenantId;
            "Authorization"    = "Bearer $($token)";
        }
    }

    [PSCustomObject] ListFiles([string] $role, [int] $pageIndex, [int] $pageSize, [string] $filter) {
        $headers = $this._defaultHeaders

        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files?role=$($role)&pageIndex=$($pageIndex)&pageSize=$($pageSize)&`$filter=$($filter)&`$orderBy=uploadDate asc" `
            -Headers $headers

        return $response
    }

    [void] DownloadFile([string] $role, [PSCustomObject] $fileInfo, [string] $downloadPath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)" `
            -Headers $headers `
            -OutFile "$($downloadPath)\$($fileInfo.Name)"
    }
}

class AuthenticationApiService {
    hidden [string] $_baseUrl
    
    AuthenticationApiService([string] $baseUrl) {
        $this._baseUrl = $baseUrl
    }

    [string] NewToken([string] $clientId, [string] $clientSecret) {
        $headers = @{
            "Content-Type"  = "application/x-www-form-urlencoded";
            "Cache-Control" = "no-cache";
        }
        $body = @{
            "grant_type"    = "client_credentials";
            "client_id"     = $clientId;
            "client_secret" = $clientSecret;
        }

        $response = Invoke-RestMethod `
            -Method "Post" `
            -Uri "$($this._baseUrl)/token" `
            -Headers $headers `
            -Body $body

        $token = $response.access_token

        return $token
    }
}

class FileNameHelper {
    static [string] ConverToUnique([string] $fileName) {
        $fileNameInfo = [FileNameHelper]::GetInfo($fileName)
        $fileNameWithoutExtension = $fileNameInfo.Name
        $fileExtension = $fileNameInfo.Extension
        $timestamp = Get-Date -Format FileDateTimeUniversal
    
        $uniqueFileName = "$($fileNameWithoutExtension) - $($timestamp)$($fileExtension)"
        return $uniqueFileName
    }

    static [PSCustomObject] GetInfo([string] $fileName) {
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
}

#endregion Classes
# This example shows how to download all the files specified in a filter.
$ErrorActionPreference = "Stop"

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
$tenantId = $config.Credentials.TenantId
$role = $Config.Credentials.Role

$waitTimeBetweenCallsMS = $config.WebClient.WaitTimeBetweenCallsMS

$filter = $config.List.Filter

$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames

# $authTokenApiBaseUrl = "https://api.raet.com/authentication"
# $fileApiBaseUrl = "https://api.raet.com/mft/v1.0"
$authTokenApiBaseUrl = "https://api-test.raet.com/authentication"
$fileApiBaseUrl = "https://api-test.raet.com/mft/v1.0"

#endregion Configuration

$authenticationApiClient = [AuthenticationApiClient]::new($authTokenApiBaseUrl)
$authenticationApiService = [AuthenticationApiService]::new($authenticationApiClient)

try {
    $token = $authenticationApiService.NewToken($clientId, $clientSecret)
    # XXX
    # $token = $config.XXXToken
}
catch {
    [Helper]::WriteDetailedError($_, "Failure while retrieving the authentication token.")
    exit 1
}

$fileApiClient = [FileApiClient]::new($fileApiBaseUrl, $token, $tenantId)
$fileApiService = [FileApiService]::new($fileApiClient, $role, $waitTimeBetweenCallsMS)

try {
    $filesInfo = $fileApiService.GetFilesInfo($filter)
}
catch {
    [Helper]::WriteDetailedError($_, "Failure while retrieving the files.")
    exit 1
}

if ($filesInfo.Count -eq 0) {
    exit
}

try {
    $fileApiService.DownloadFiles($filesInfo, $downloadPath, $ensureUniqueNames)
}
catch {
    [Helper]::WriteDetailedError($_, "Failure while downloading the files.")
    exit 1
}

# -------- END OF THE PROGRAM --------
# Bellow there are classes to help the readability of the program

#region Helper_classes

class FileApiService {
    hidden [FileApiClient] $_fileApiClient
    hidden [string] $_role
    hidden [string] $_waitTimeBetweenCallsMS

    FileApiService (
        [FileApiClient] $fileApiClient,
        [string] $role,
        [int] $waitTimeBetweenCallsMS
    ) {
        $this._fileApiClient = $fileApiClient
        $this._role = $role
        $this._waitTimeBetweenCallsMS = $waitTimeBetweenCallsMS
    }

    [PSCustomObject] GetFilesInfo([string] $filter) {
        Write-Host "----"
        Write-Host "Retrieving list of files."
        if ($filter) {
            Write-Host "| Filter: $($filter)"
        }

        $pageIndex = 0
        $pageSize = 20
        $isLastPage = $false
        $filesInfo = @()
        do {
            $response = $this._fileApiClient.ListFiles($this._role, $pageIndex, $pageSize, $filter)

            foreach ($fileData in $response.data) {
                $filesInfo += @{
                    Id   = $fileData.fileId
                    Name = $fileData.fileName
                    Size = $fileData.fileSize
                }
            }

            $isLastPage = $pageSize * ($pageIndex + 1) -ge $response.count
            $pageIndex++

            Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS
        } while (-not $isLastPage)

        Write-Host "$($filesInfo.Count) files retrieved."

        return $filesInfo
    }

    [void] DownloadFiles([PSCustomObject[]] $filesInfo, [string] $path, [bool] $ensureUniqueNames) {
        $downloadedFilesCount = 0
        foreach ($fileInfo in $filesInfo) {
            Write-Host "----"
            Write-Host "Downloading file $($downloadedFilesCount + 1)/$($filesInfo.Count)."
            Write-Host "| ID: $($fileInfo.Id)"
            Write-Host "| Name: $($fileInfo.Name)"

            if (($ensureUniqueNames -eq $true) -and (Test-Path "$($path)\$($fileInfo.Name)" -PathType Leaf)) {
                Write-Host "There is already a file with the same name in the download path."

                $fileInfo.Name = [Helper]::ConverToUniqueFileName($fileInfo.Name)

                Write-Host "| New name: $($fileInfo.Name)"
            }

            $this._fileApiClient.DownloadFile($this._role, $fileInfo, $path)
            $downloadedFilesCount++
        
            Write-Host "The file was downloaded."

            Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS
        }

        Write-Host "----"
        Write-Host "All files were downloaded."
        Write-Host "| Amount: $($downloadedFilesCount)"
        Write-Host "| Path: $($path)"
    }
}

class FileApiClient {
    [string] $BaseUrl
    
    hidden [PSCustomObject] $_defaultHeaders

    FileApiClient (
        [string] $baseUrl,
        [string] $token,
        [string] $tenantId
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

    [PSCustomObject] DownloadFile([string] $role, [PSCustomObject] $fileInfo, [string] $downloadPath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)" `
            -Headers $headers `
            -OutFile "$($downloadPath)\$($fileInfo.Name)"

        return $response
    }
}

class AuthenticationApiService {
    hidden [AuthenticationApiClient] $_authenticationApiClient

    AuthenticationApiService([AuthenticationApiClient] $authenticationApiClient) {
        $this._authenticationApiClient = $authenticationApiClient
    }

    [string] NewToken([string] $clientId, [string] $clientSecret) {
        Write-Host "----"
        Write-Host "Retrieving the authentication token."

        $response = $this._authenticationApiClient.NewToken($clientId, $clientSecret)
        $token = $response.access_token

        Write-Host "Authentication token retrieved."

        return $token
    }
}

class AuthenticationApiClient {
    hidden [string] $_baseUrl
    
    AuthenticationApiClient([string] $baseUrl) {
        $this._baseUrl = $baseUrl
    }

    [PSCustomObject] NewToken([string] $clientId, [string] $clientSecret) {
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

        return $response
    }
}

class Helper {
    static [string] ConverToUniqueFileName([string] $fileName) {
        $fileNameInfo = [Helper]::GetFileNameInfo($fileName)
        $fileNameWithoutExtension = $fileNameInfo.Name
        $fileExtension = $fileNameInfo.Extension
        $timestamp = Get-Date -Format FileDateTimeUniversal
    
        $uniqueFileName = "$($fileNameWithoutExtension) - $($timestamp)$($fileExtension)"
        return $uniqueFileName
    }

    static [PSCustomObject] GetFileNameInfo([string] $fileName) {
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

    static [void] WriteDetailedError([System.Management.Automation.ErrorRecord] $errorRecord, [string] $genericErrorMessage) {
        Write-Host "ERROR - $($genericErrorMessage)" -ForegroundColor "Red"

        $errorMessage = "Unknown error."
        if ($errorRecord.ErrorDetails.Message) {
            $errorDetails = $errorRecord.ErrorDetails.Message | ConvertFrom-Json
            if ($errorDetails.message) {
                $errorMessage = $errorDetails.message
            }
            elseif ($errorDetails.error.message) {
                $errorMessage = $errorDetails.error.message
            }
        }
        elseif ($errorRecord.Exception.message) {
            $errorMessage = $errorRecord.Exception.message
        }

        Write-Host "| Error message: $($errorMessage)" -ForegroundColor "Red"
        Write-Host "| Line: $($errorRecord.InvocationInfo.ScriptLineNumber)" -ForegroundColor "Red"
    }
}

#endregion Helper_classes

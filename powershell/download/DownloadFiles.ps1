# This example shows how to download all the files specified in a filter.
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(Mandatory = $false, HelpMessage = 'Full path of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\download\config.xml). If not provided the default configuration will be used.')]
    [string] $configurationPath
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================="
Write-Host "File API example: Download files specified in a filter."
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

try {
    Write-Host "----"
    Write-Host "Retrieving the configuration."
    
    if (-not $configurationPath) {
        $configurationPath = "$($PSScriptRoot)\config.xml"
    }

    if (-not (Test-Path $configurationPath -PathType Leaf)) {
        throw "Configuration not found.`r`n| Path: $configurationPath"
    }
    
    $configDocument = [xml](Get-Content $configurationPath)
    $config = $configDocument.Configuration

    $clientId = $config.Credentials.ClientId
    $clientSecret = $config.Credentials.ClientSecret

    $fileApiBaseUrl = $config.Services.FileApiBaseUrl
    $authTokenApiBaseUrl = $config.Services.AuthenticationTokenApiBaseUrl
    
    $tenantId = $config.Download.TenantId
    $role = $Config.Download.Role
    $downloadPath = $config.Download.Path
    $ensureUniqueNames = [System.Convert]::ToBoolean($config.Download.EnsureUniqueNames)
    $filter = $config.Download.Filter

    Write-Host "Configuration retrieved."
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.")
}

$authenticationApiClient = [AuthenticationApiClient]::new($authTokenApiBaseUrl)
$authenticationApiService = [AuthenticationApiService]::new($authenticationApiClient)

try {
    $token = $authenticationApiService.NewToken($clientId, $clientSecret)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.")
}

$fileApiClient = [FileApiClient]::new($fileApiBaseUrl, $token, $tenantId)
$fileApiService = [FileApiService]::new($fileApiClient, $role, 200)

try {
    $filesInfo = $fileApiService.GetFilesInfo($filter)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the files.")
}

if ($filesInfo.Count -eq 0) {
    [Helper]::EndProgram()
}

try {
    $fileApiService.DownloadFiles($filesInfo, $downloadPath, $ensureUniqueNames)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure downloading the files.")
}

[Helper]::EndProgram()

# -------- END OF THE PROGRAM --------
# Below there are classes and models to help the readability of the program

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

    [FileInfo[]] GetFilesInfo([string] $filter) {
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
                $fileInfo = [FileInfo]::new()
                $fileInfo.Id = $fileData.fileId
                $fileInfo.Name = $fileData.fileName
                $fileInfo.Size = $fileData.fileSize

                $filesInfo += $fileInfo
            }

            $isLastPage = $pageSize * ($pageIndex + 1) -ge $response.count
            $pageIndex++

            Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS
        } while (-not $isLastPage)

        Write-Host "$($filesInfo.Count) files retrieved."

        return $filesInfo
    }

    [void] DownloadFiles([FileInfo[]] $filesInfo, [string] $path, [bool] $ensureUniqueNames) {
        if (-not (Test-Path $path -PathType Container)) {
            Write-Host "----"
            Write-Host "Download path doesn't exist. Creating it."
            Write-Host "| Path: $($path)"
            
            New-Item -ItemType Directory -Force -Path $path
        }

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

    [PSCustomObject] DownloadFile([string] $role, [FileInfo] $fileInfo, [string] $downloadPath) {
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
    
        $uniqueFileName = "$($fileNameWithoutExtension)_$($timestamp)$($fileExtension)"
        return $uniqueFileName
    }

    static [FileNameInfo] GetFileNameInfo([string] $fileName) {
        $fileNameInfo = [FileNameInfo]::new()
        $fileNameInfo.Name = $fileName
        $fileNameInfo.Extension = ""
        
        $splitFileName = $fileName -split "\."
        if ($splitFileName.Length -gt 1) {
            $fileNameInfo.Name = $splitFileName[0..($splitFileName.Length - 2)] -Join "."
            $fileNameInfo.Extension = ".$($splitFileName[-1])"
        }
    
        return $fileNameInfo
    }

    static [void] EndProgram() {
        [helper]::FinishProgram($false)
    }

    static [void] EndProgramWithError([System.Management.Automation.ErrorRecord] $errorRecord, [string] $genericErrorMessage) {
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
        Write-Host "| Error line in the script: $($errorRecord.InvocationInfo.ScriptLineNumber)" -ForegroundColor "Red"

        [helper]::FinishProgram($true)
    }

    hidden static [void] FinishProgram([bool] $finishWithError) {
        Write-Host "---"
        Write-Host "End of the example."

        if ($finishWithError) {
            exit 1
        }
        else {
            exit
        }
    }
}

#endregion Helper_classes

#region Models

class FileInfo {
    [string] $Id
    [string] $Name
    [long] $Size
}

class FileNameInfo {
    [string] $Name
    [string] $Extension
}

#endregion Models

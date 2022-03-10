# This example shows how to download all the files specified in a filter.
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Full path of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\download\config.xml). Default value: set in the code.'
    )]
    [string] $_configPath = "$($PSScriptRoot)\config.xml",

    [Alias("RenewCredentials")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Boolean indicating if you want to renew your credentials (true) / or not (false). Default value: false.\nThis parameter is useful in case you changed your ClientId or Client secret.'
    )]
    [bool] $_renewCredentials = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================="
Write-Host "File API example: Download files specified in a filter."
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

try {
    Write-Host "----"
    Write-Host "Retrieving the configuration."

    if (-not (Test-Path $_configPath -PathType Leaf)) {
        throw "Configuration not found.`r`n| Path: $_configPath"
    }
    
    $configDocument = [xml](Get-Content $_configPath)
    $config = $configDocument.Configuration

    $credentialsStoragePath = $config.Credentials.StoragePath

    $fileApiBaseUrl = $config.Services.FileApiBaseUrl
    $authenticationTokenApiBaseUrl = $config.Services.AuthenticationTokenApiBaseUrl
    
    $tenantId = $config.Download.TenantId
    $role = $Config.Download.Role
    $downloadPath = $config.Download.Path
    $ensureUniqueNames = $config.Download.EnsureUniqueNames
    $filter = $config.Download.Filter

    $missingConfiguration = @()
    if ([string]::IsNullOrEmpty($credentialsStoragePath)) { $missingConfiguration += "Credentials.StoragePath" }
    if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
    if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
    if ([string]::IsNullOrEmpty($tenantId)) { $missingConfiguration += "Download.TenantId" }
    if ([string]::IsNullOrEmpty($role)) { $missingConfiguration += "Download.Role" }
    if ([string]::IsNullOrEmpty($downloadPath)) { $missingConfiguration += "Download.Path" }
    if ([string]::IsNullOrEmpty($ensureUniqueNames)) { $missingConfiguration += "Download.EnsureUniqueNames" }
    if ($null -eq $filter) { $missingConfiguration += "Download.Filter" }

    if ($missingConfiguration.Count -gt 0) {
        throw "Missing parameters: $($missingConfiguration -Join ", ")"
    }

    $wrongConfiguration = @()    
    if (-not [bool]::TryParse($ensureUniqueNames, [ref] $ensureUniqueNames)) { $wrongConfiguration += "Download.EnsureUniqueNames" }

    if ($wrongConfiguration.Count -gt 0) {
        throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
    }

    Write-Host "Configuration retrieved."
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.")
}

[CredentialsManager] $credentialsManager = [CredentialsManager]::new($credentialsStoragePath)
[CredentialsService] $credentialsService = [CredentialsService]::new($credentialsManager)

try {
    $credentials = $credentialsService.Retrieve($_renewCredentials)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the credentials.")
}

[AuthenticationApiClient] $authenticationApiClient = [AuthenticationApiClient]::new($authenticationTokenApiBaseUrl)
[AuthenticationApiService] $authenticationApiService = [AuthenticationApiService]::new($authenticationApiClient)

try {
    $token = $authenticationApiService.NewToken($credentials.ClientId, $credentials.ClientSecret)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.")
}

[FileApiClient] $fileApiClient = [FileApiClient]::new($fileApiBaseUrl, $token, $tenantId)
[FileApiService] $fileApiService = [FileApiService]::new($fileApiClient, $role, 200)

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

class CredentialsService {
    hidden [CredentialsManager] $_credentialsManager

    CredentialsService ([CredentialsManager] $credentialsManager) {
        $this._credentialsManager = $credentialsManager
    }

    [Credentials] Retrieve([bool] $renewCredentials) {
        if ($renewCredentials) {
            $this._credentialsManager.CreateNew()
            $credentials = $this._credentialsManager.Retrieve()
    
            return $credentials
        }
        
        $credentials = $this._credentialsManager.Retrieve()
        if ($null -eq $credentials) {
            $credentials = $this._credentialsManager.CreateNew()
        }
    
        return $credentials
    }
}

class CredentialsManager {
    hidden [string] $_storagePath
    hidden [string] $_storageFileName

    CredentialsManager([string] $storagePath) {
        $this._storagePath = $storagePath
        $this._storageFileName = "credentials.xml"
    }

    [void] CreateNew() {
        $storageFullPath = "$($this._storagePath)\$($this._storageFileName)"

        Write-Host "----"
        Write-Host "Saving your credentials."
        Write-Host "| Path: $($storageFullPath)"

        if (-not (Test-Path -Path $this._storagePath -PathType Container)) {
            Write-Host "----"
            Write-Host "Storage credential path doesn't exist. Creating it."
            Write-Host "| Path: $($this._storagePath)"
            
            New-Item -ItemType Directory -Force -Path $this._storagePath
        }

        Write-Host "Enter your credentials."
        $clientId = Read-Host -Prompt '| Client ID'
        $clientSecret = Read-Host -Prompt '| Client secret' -AsSecureString

        [PSCredential]::new($clientId, $clientSecret) | Export-CliXml -Path $storageFullPath

        Write-Host "----"
        Write-Host "Credentials saved."
    }

    [Credentials] Retrieve() {
        $storageFullPath = "$($this._storagePath)\$($this._storageFileName)"

        Write-Host "----"
        Write-Host "Retrieving your credentials."
        Write-Host "| Path: $($storageFullPath)"

        if (-not (Test-Path -Path $storageFullPath -PathType Leaf)) {
            Write-Host "----"
            Write-Host "Credentials not found."
            Write-Host "| Path: $($storageFullPath)"
            
            return $null
        }

        $credentialsStorage = Import-CliXml -Path $storageFullPath

        $credentials = [Credentials]::new()
        $credentials.ClientId = $credentialsStorage.GetNetworkCredential().UserName
        $credentials.ClientSecret = $credentialsStorage.GetNetworkCredential().Password

        Write-Host "Credentials retrieved."

        return $credentials
    }
}

class FileApiService {
    hidden [FileApiClient] $_fileApiClient
    hidden [string] $_role
    hidden [string] $_waitTimeBetweenCallsMS
    hidden [long] $_downloadSizeLimit

    FileApiService(
        [FileApiClient] $fileApiClient,
        [string] $role,
        [int] $waitTimeBetweenCallsMS
    ) {
        $this._fileApiClient = $fileApiClient
        $this._role = $role
        $this._waitTimeBetweenCallsMS = $waitTimeBetweenCallsMS

        # This limit is set because the method Invoke-RestMethod doesn't allow
        # the download of files bigger than 2 GiB.
        # I set the limit a bit less than 2 GiB to give some margin.
        $this._downloadSizeLimit = 2147000000
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
            Write-Host "| Size: $($fileInfo.Size)"

            if ($fileInfo.Size -ge $this._downloadSizeLimit) {
                Write-Host "---" -ForegroundColor "Red"
                Write-Host "Cannot download files bigger or equal than $($this._downloadSizeLimit) bytes." -ForegroundColor "Red"
                Write-Host "File will be skipped." -ForegroundColor "Red"

                continue
            }

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
        Write-Host "----"
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

class Credentials {
    [string] $ClientId
    [string] $ClientSecret
}

#endregion Models

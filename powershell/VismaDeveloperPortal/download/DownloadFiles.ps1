# This example shows how to download all the files specified in a filter.
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Full path of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\download\config.xml). Default value: set in the code.'
    )]
    [string] $_configPath,

    [Alias("RenewCredentials")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Boolean. $true if you want to renew your credentials. $false otherwise.'
    )]
    [bool] $_renewCredentials = $false
)

$ErrorActionPreference = "Stop"

# The default value of this parameter is set here because $PSScriptRoot is empty if used directly in Param() through PowerShell ISE.
if (-not $_configPath) {
    $_configPath = "$($PSScriptRoot)\config.xml"
}

#region Log configuration

try {
    $logConfig = [ConfigurationManager]::GetLogConfiguration($_configPath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the logger configuration. Tip: see the README.MD to check the format of the parameters.", $null)
}

[Logger] $logger = [Logger]::new($logConfig.Enabled, $logConfig.Path)

#endregion Log configuration

$logger.LogInformation("==============================================")
$logger.LogInformation("File API integration example: Download files.")
$logger.LogInformation("==============================================")
$logger.LogInformation("(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')")
$logger.LogInformation("PowerShell version: $($global:PSVersionTable.PSVersion)")

#region Rest of the configuration

try {
    $config = [ConfigurationManager]::GetConfiguration($_configPath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.", $logger)
}

#endregion Rest of the configuration

#region Retrieve/Create credentials

$credentialsManager = [CredentialsManager]::new($logger, $config.Credentials.Path)
$credentialsService = [CredentialsService]::new($credentialsManager, $config.Credentials.TenantId)

try {
    if ($_renewCredentials) {
        $credentials = $credentialsService.CreateNew()
    }
    else {
        $credentials = $credentialsService.Retrieve()
    }
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the credentials.", $logger)
}

#endregion Retrieve/Create credentials

#region Retrieve authentication token

$authenticationApiClient = [AuthenticationApiClient]::new($config.Services.AuthenticationTokenApiBaseUrl)
$authenticationApiService = [AuthenticationApiService]::new($logger, $authenticationApiClient)

try {
    $token = $authenticationApiService.NewToken($credentials.ClientId, $credentials.ClientSecret, $credentials.TenantId)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.", $logger)
}

#endregion Retrieve authentication token

$fileApiClient = [FileApiClient]::new($config.Services.FileApiBaseUrl, $token)
$fileApiService = [FileApiService]::new($logger, $fileApiClient, $config.Download.Role, 200)

#region List files

try {
    $filesInfo = $fileApiService.GetFilesInfo($config.Download.Filter)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the files.", $logger)
}

if ($filesInfo.Count -eq 0) {
    [Helper]::EndProgram($logger)
}

#endregion List files

#region Download files

try {
    $fileApiService.DownloadFiles($filesInfo, $config.Download.Path, $config.Download.EnsureUniqueNames)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure downloading the files.". $logger)
}

#endregion Download files

[Helper]::EndProgram($logger)

# -------- END OF THE PROGRAM --------
# Below there are classes and models to help the readability of the program

#region Helper classes

class ConfigurationManager {
    static [ConfigurationSectionLogs] GetLogConfiguration($configPath) {
        if (-not (Test-Path $configPath -PathType Leaf)) {
            throw "Configuration not found.`r`n| Path: $($configPath)"
        }
        
        $configDocument = [xml](Get-Content $configPath)
        $config = $configDocument.Configuration
    
        $enableLogs = $config.Logs.Enabled
        $logsPath = $config.Logs.Path

        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($enableLogs)) { $missingConfiguration += "Logs.Enabled" }
        if ([string]::IsNullOrEmpty($logsPath)) { $missingConfiguration += "Logs.Path" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }

        $wrongConfiguration = @()
        if (-not [Validator]::IsBool($enableLogs)) { $wrongConfiguration += "Logs.Enabled" }
        if (-not [Validator]::IsPath($logsPath)) { $wrongConfiguration += "Logs.Path" }
    
        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        $logConfiguration = [ConfigurationSectionLogs]::new()
        $logConfiguration.Enabled = [System.Convert]::ToBoolean($enableLogs)
        $logConfiguration.Path = $logsPath

        return $logConfiguration
    }

    static [Configuration] GetConfiguration($configPath) {
        if (-not (Test-Path $configPath -PathType Leaf)) {
            throw "Configuration not found.`r`n| Path: $($configPath)"
        }
        
        $configDocument = [xml](Get-Content $configPath)
        $config = $configDocument.Configuration
    
        $credentialsPath = $config.Credentials.Path
    
        $fileApiBaseUrl = $config.Services.FileApiBaseUrl
        $authenticationTokenApiBaseUrl = $config.Services.AuthenticationTokenApiBaseUrl
        
        $vismaConnectTenantId = $config.Authentication.VismaConnectTenantId

        $enableLogs = $config.Logs.Enabled
        $logsPath = $config.Logs.Path

        $role = $Config.Download.Role
        $downloadPath = $config.Download.Path
        $ensureUniqueNames = $config.Download.EnsureUniqueNames
        $filter = $config.Download.Filter
    
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($credentialsPath)) { $missingConfiguration += "Credentials.Path" }
        if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
        if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if ([string]::IsNullOrEmpty($vismaConnectTenantId)) { $missingConfiguration += "Authentication.VismaConnectTenantId" }
        if ([string]::IsNullOrEmpty($enableLogs)) { $missingConfiguration += "Logs.Enabled" }
        if ([string]::IsNullOrEmpty($logsPath)) { $missingConfiguration += "Logs.Path" }
        if ([string]::IsNullOrEmpty($role)) { $missingConfiguration += "Download.Role" }
        if ([string]::IsNullOrEmpty($downloadPath)) { $missingConfiguration += "Download.Path" }
        if ([string]::IsNullOrEmpty($ensureUniqueNames)) { $missingConfiguration += "Download.EnsureUniqueNames" }
        if ($null -eq $filter) { $missingConfiguration += "Download.Filter" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }
    
        $wrongConfiguration = @()
        if (-not [Validator]::IsPath($credentialsPath)) { $wrongConfiguration += "Credentials.Path" }
        if (-not [Validator]::IsUri($fileApiBaseUrl)) { $wrongConfiguration += "Services.FileApiBaseUrl" }
        if (-not [Validator]::IsUri($authenticationTokenApiBaseUrl)) { $wrongConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if (-not [Validator]::IsBool($enableLogs)) { $wrongConfiguration += "Logs.Enabled" }
        if (-not [Validator]::IsPath($logsPath)) { $wrongConfiguration += "Logs.Path" }
        if (-not [Validator]::IsBool($ensureUniqueNames)) { $wrongConfiguration += "Download.EnsureUniqueNames" }
        if (-not [Validator]::IsPath($downloadPath)) { $wrongConfiguration += "Download.Path" }
    
        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        $configuration = [Configuration]::new()
        $configuration.Credentials.Path = $credentialsPath
        $configuration.Credentials.TenantId = $vismaConnectTenantId
        $configuration.Services.FileApiBaseUrl = $fileApiBaseUrl
        $configuration.Services.AuthenticationTokenApiBaseUrl = $authenticationTokenApiBaseUrl
        $configuration.Logs.Enabled = [System.Convert]::ToBoolean($enableLogs)
        $configuration.Logs.Path = $logsPath
        $configuration.Download.Role = $role
        $configuration.Download.Path = $downloadPath
        $configuration.Download.EnsureUniqueNames = [System.Convert]::ToBoolean($ensureUniqueNames)
        $configuration.Download.Filter = $filter

        return $configuration
    }
}

class CredentialsService {
    hidden [CredentialsManager] $_credentialsManager
    hidden [string] $_tenantId

    CredentialsService ([CredentialsManager] $manager, [string] $tenantId) {
        $this._credentialsManager = $manager
        $this._tenantId = $tenantId
    }

    [Credentials] Retrieve() {
        $credentials = $this._credentialsManager.Retrieve()
        if ($null -eq $credentials) {
            $credentials = $this.CreateNew()
            $credentials.TenantId = $this._tenantId

            return $credentials
        }
        $credentials.TenantId = $this._tenantId

        return $credentials
    }

    [Credentials] CreateNew() {
        $this._credentialsManager.CreateNew()
        $credentials = $this._credentialsManager.Retrieve()
        $credentials.TenantId = $this._tenantId

        return $credentials
    }
}

class CredentialsManager {
    hidden [Logger] $_logger
    hidden [string] $_credentialsPath

    CredentialsManager([Logger] $logger, [string] $storagePath) {
        $this._logger = $logger
        $this._credentialsPath = $storagePath
    }

    [void] CreateNew() {
        $storagePath = Split-Path $this._credentialsPath
        
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Saving your credentials.")
        $this._logger.LogInformation("| Path: $($this._credentialsPath)")

        if (-not (Test-Path -Path $storagePath -PathType Container)) {
            $this._logger.LogInformation("----")
            $this._logger.LogInformation("Storage credential path doesn't exist. Creating it.")
            $this._logger.LogInformation("| Path: $($storagePath)")
            
            New-Item -ItemType Directory -Path $storagePath -Force
        }

        $this._logger.LogInformation("Enter your credentials.")
        $clientId = Read-Host -Prompt '| Client ID'
        $clientSecret = Read-Host -Prompt '| Client secret' -AsSecureString

        [PSCredential]::new($clientId, $clientSecret) | Export-CliXml -Path $this._credentialsPath

        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Credentials saved.")
    }

    [Credentials] Retrieve() {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Retrieving your credentials.")
        $this._logger.LogInformation("| Path: $($this._credentialsPath)")

        if (-not (Test-Path -Path $this._credentialsPath -PathType Leaf)) {
            $this._logger.LogInformation("----")
            $this._logger.LogInformation("Credentials not found.")
            $this._logger.LogInformation("| Path: $($this._credentialsPath)")
            
            return $null
        }

        $credentialsStorage = Import-CliXml -Path $this._credentialsPath

        $credentials = [Credentials]::new()
        $credentials.ClientId = $credentialsStorage.GetNetworkCredential().UserName
        $credentials.ClientSecret = $credentialsStorage.GetNetworkCredential().Password

        $this._logger.LogInformation("Credentials retrieved.")

        return $credentials
    }
}

class FileApiService {
    hidden [Logger] $_logger
    hidden [FileApiClient] $_fileApiClient
    hidden [string] $_role
    hidden [string] $_waitTimeBetweenCallsMS
    hidden [long] $_downloadSizeLimit

    FileApiService(
        [Logger] $logger,
        [FileApiClient] $fileApiClient,
        [string] $role,
        [int] $waitTimeBetweenCallsMS
    ) {
        $this._logger = $logger
        $this._fileApiClient = $fileApiClient
        $this._role = $role
        $this._waitTimeBetweenCallsMS = $waitTimeBetweenCallsMS

        # This limit is set because the method Invoke-RestMethod doesn't allow
        # the download of files bigger than 2 GiB.
        # I set the limit a bit less than 2 GiB to give some margin.
        $this._downloadSizeLimit = 2147000000
    }

    [FileInfo[]] GetFilesInfo([string] $filter) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Retrieving list of files.")
        if ($filter) {
            $this._logger.LogInformation("| Filter: $($filter)")
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

        $this._logger.LogInformation("$($filesInfo.Count) files retrieved.")

        return $filesInfo
    }

    [void] DownloadFiles([FileInfo[]] $filesInfo, [string] $path, [bool] $ensureUniqueNames) {
        if (-not (Test-Path $path -PathType Container)) {
            $this._logger.LogInformation("----")
            $this._logger.LogInformation("Download path doesn't exist. Creating it.")
            $this._logger.LogInformation("| Path: $($path)")
            
            New-Item -ItemType Directory -Path $path -Force
        }

        $downloadedFilesCount = 0
        foreach ($fileInfo in $filesInfo) {
            $this._logger.LogInformation("----")
            $this._logger.LogInformation("Downloading file $($downloadedFilesCount + 1)/$($filesInfo.Count).")
            $this._logger.LogInformation("| ID: $($fileInfo.Id)")
            $this._logger.LogInformation("| Name: $($fileInfo.Name)")
            $this._logger.LogInformation("| Size: $($fileInfo.Size)")

            if ($fileInfo.Size -ge $this._downloadSizeLimit) {
                $this._logger.LogError("----")
                $this._logger.LogError("Cannot download files bigger or equal than $($this._downloadSizeLimit) bytes.")
                $this._logger.LogError("File will be skipped.")

                continue
            }

            if (($ensureUniqueNames -eq $true) -and (Test-Path "$($path)\$($fileInfo.Name)" -PathType Leaf)) {
                $this._logger.LogInformation("There is already a file with the same name in the download path.")

                $fileInfo.Name = [Helper]::ConverToUniqueFileName($fileInfo.Name)

                $this._logger.LogInformation("| New name: $($fileInfo.Name)")
            }

            $this._fileApiClient.DownloadFile($this._role, $fileInfo, $path)
            $downloadedFilesCount++
        
            $this._logger.LogInformation("The file was downloaded.")

            Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS
        }

        $this._logger.LogInformation("----")
        $this._logger.LogInformation("All files were downloaded.")
        $this._logger.LogInformation("| Amount: $($downloadedFilesCount)")
        $this._logger.LogInformation("| Path: $($path)")
    }
}

class FileApiClient {
    [string] $BaseUrl
    
    hidden [PSCustomObject] $_defaultHeaders

    FileApiClient (
        [string] $baseUrl,
        [string] $token
    ) {
        $this.BaseUrl = $baseUrl
        $this._defaultHeaders = @{
            "Authorization" = "Bearer $($token)";
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
    hidden [Logger] $_logger
    hidden [AuthenticationApiClient] $_authenticationApiClient

    AuthenticationApiService([Logger] $logger, [AuthenticationApiClient] $authenticationApiClient) {
        $this._logger = $logger
        $this._authenticationApiClient = $authenticationApiClient
    }

    [string] NewToken([string] $clientId, [string] $clientSecret, [string] $tenantId) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Retrieving the authentication token.")

        $response = $this._authenticationApiClient.NewToken($clientId, $clientSecret, $tenantId)
        $token = $response.access_token

        $this._logger.LogInformation("Authentication token retrieved.")

        return $token
    }
}

class AuthenticationApiClient {
    hidden [string] $_baseUrl
    
    AuthenticationApiClient([string] $baseUrl) {
        $this._baseUrl = $baseUrl
    }

    [PSCustomObject] NewToken([string] $clientId, [string] $clientSecret, [string] $tenantId) {
        $headers = @{
            "Content-Type"  = "application/x-www-form-urlencoded";
            "Cache-Control" = "no-cache";
        }
        $body = @{
            "grant_type"    = "client_credentials";
            "client_id"     = $clientId;
            "client_secret" = $clientSecret;
            "tenant_id"     = $tenantId;
        }

        $response = Invoke-RestMethod `
            -Method "Post" `
            -Uri "$($this._baseUrl)/token" `
            -Headers $headers `
            -Body $body

        return $response
    }
}

class Validator {
    static [bool] IsUri([string] $testParameter) {
        try {
            $uri = $testParameter -As [System.Uri]

            if ($uri.AbsoluteUri) {
                return $true
            }
            else {
                return $false
            }
        }
        catch {
            return $false
        }
    }

    static [bool] IsBool([string] $testParameter) {
        try {
            $result = [bool]::TryParse($testParameter, [ref] $null)
            return $result
        }
        catch {
            return $false
        }
    }

    static [bool] IsPath([string] $testParameter) {
        try {
            $result = Test-Path $testParameter -IsValid
            return $result
        }
        catch {
            return $false
        }
    }
}

class Logger {
    hidden [bool] $_storeLogs
    hidden [string] $_logPath

    Logger([bool] $storeLogs, [string] $logsDirectory) {
        $this._storeLogs = $storeLogs

        if ($this._storeLogs) {
            $this._logPath = Join-Path $logsDirectory "download log - $(Get-Date -Format "yyyy-MM-dd").txt"
        
            if (-not (Test-Path -Path $logsDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $logsDirectory -Force
            }
        }
    }

    [void] LogInformation([string] $text) {
        $text = "$(Get-Date -Format "yy/MM/dd HH:mm:ss") [Information] $($text)"
        
        Write-Host $text
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }

    [void] LogError([string] $text) {
        $text = "$(Get-Date -Format "yy/MM/dd HH:mm:ss") [Error] $($text)"

        Write-Host $text -ForegroundColor "Red"
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }
}

class Helper {
    static [string] ConverToUniqueFileName([string] $fileName) {
        $fileNameInfo = [Helper]::GetFileNameInfo($fileName)
        $fileNameWithoutExtension = $fileNameInfo.Name
        $fileExtension = $fileNameInfo.Extension
        $timestamp = Get-Date -Format "yyyyMMddTHHmmssffffZ"
    
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

    static [void] EndProgram([Logger] $logger) {
        [Helper]::FinishProgram($false, $logger)
    }

    static [void] EndProgramWithError([System.Management.Automation.ErrorRecord] $errorRecord, [string] $genericErrorMessage, [Logger] $logger) {
        if (-not $logger) {
            $logger = [Logger]::new($false, "")
        }

        $logger.LogError($genericErrorMessage)

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

        $logger.LogError("| Error message: $($errorMessage)")
        $logger.LogError("| Error line in the script: $($errorRecord.InvocationInfo.ScriptLineNumber)")

        [Helper]::FinishProgram($true, $logger)
    }

    hidden static [void] FinishProgram([bool] $finishWithError, [Logger] $logger) {
        if (-not $logger) {
            $logger = [Logger]::new($false, "")
        }

        $logger.LogInformation("----")
        $logger.LogInformation("End of the example.`n")

        if ($finishWithError) {
            exit 1
        }
        else {
            exit
        }
    }
}

#endregion Helper classes

#region Models

class Configuration {
    $Credentials = [ConfigurationSectionCredentials]::new()
    $Services = [ConfigurationSectionServices]::new()
    $Logs = [ConfigurationSectionLogs]::new()
    $Download = [ConfigurationSectionDownload]::new()
}

class ConfigurationSectionCredentials {
    [string] $Path
    [string] $TenantId
}

class ConfigurationSectionServices {
    [string] $FileApiBaseUrl
    [string] $AuthenticationTokenApiBaseUrl
}

class ConfigurationSectionLogs {
    [bool] $Enabled
    [string] $Path
}

class ConfigurationSectionDownload {
    [string] $Role
    [string] $Path
    [bool] $EnsureUniqueNames
    [string] $Filter
}

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
    [string] $TenantId
}

#endregion Models

# This example shows how to upload a file. 
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Full filePath of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\upload\config.xml). Default value: set in the code.'
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
$scriptMajorVersion = 1
$scriptMinorVersion = 23

# The default value of this parameter is set here because $PSScriptRoot is empty if used directly in Param() through PowerShell ISE.
if (-not $_configPath) {
    $_configPath = "$($PSScriptRoot)\config.xml"
}

# Place in this variable the paths of all the resources which you want to ensure their removal after each execution.
$script:temporaryResourcesPaths = @()

#region Log configuration

try {
    $logConfig = [ConfigurationManager]::GetLogConfiguration($_configPath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the logger configuration. Tip: see the README.MD to check the format of the parameters.", $null)
}

[Logger] $logger = [Logger]::new($logConfig.Enabled, $logConfig.Path, $logConfig.MonitorFile, "UPLOAD")

$logger.LogRaw("")
$logger.LogInformation("=============================================================")
$logger.LogInformation("File API integration example: Upload files from a directory.")
$logger.LogInformation("=============================================================")
$logger.LogInformation("(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')")
$logger.LogInformation("Versions:")
$logger.LogInformation("| Script     : $($scriptMajorVersion).$($scriptMinorVersion).")
$logger.LogInformation("| PowerShell : $($global:PSVersionTable.PSVersion).")
$logger.LogInformation("| Windows    : $(if (($env:OS).Contains("Windows")) { [Helper]::RetrieveWindowsVersion() } else { "Unknown OS system detected" }).")
$logger.LogInformation("| NET version: $([Helper]::GetDotNetFrameworkVersion().Version)")

$logger.MonitorInformation("Upload script started with config $($(Split-Path -Path $_configPath -Leaf))")

#region Rest of the configuration

try {
    $config = [ConfigurationManager]::GetConfiguration($_configPath)
}
catch {
    $logger.MonitorError("Failure reading the configuration file")
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.", $logger)
}

#endregion Rest of the configuration

#endregion Log configuration

#region Network settings

# Pick defaults for proxy
[System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Set TLS1.2 as security Protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#endregion Network settings

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
    $logger.MonitorError("Failure retrieving the credentials")
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
    $logger.MonitorError("Failure retrieving the authentication token")
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.", $logger)
}

#endregion Retrieve authentication token

#region Upload directory contents

$fileApiClient = [FileApiClient]::new($config.Services.FileApiBaseUrl, $token)
$fileApiService = [FileApiService]::new($logger, $fileApiClient, $config.Upload.BusinessTypeId, $config.Upload.ChunkSize)

try {
    $fileApiService.UploadAndArchiveFiles($config.Upload.Path, $config.Upload.Filter, $config.Upload.ArchivePath)
}
catch {
    $logger.MonitorError("Failure uploading files : $($_)")
    [Helper]::EndProgramWithError($_, "Failure uploading the file(s).", $logger)
}

#endregion Upload directory contents

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
        $monitorFile = $config.Logs.MonitorFile


        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($enableLogs)) { $missingConfiguration += "Logs.Enabled" }
        if ([string]::IsNullOrEmpty($logsPath)) { $missingConfiguration += "Logs.Path" }
        if ([string]::IsNullOrEmpty($monitorFile)) { $missingConfiguration += "Logs.MonitorFile" }

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
        $logConfiguration.MonitorFile = $monitorFile

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

        $businessTypeId = $config.Upload.BusinessTypeId
        $contentDirectoryPath = $config.Upload.Path
        $contentFilter = $config.Upload.Filter
        $archivePath = $config.Upload.ArchivePath
        $chunkSize = [long] $config.Upload.ChunkSize 
        $chunkSizeLimit = [long] 100
    
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($credentialsPath)) { $missingConfiguration += "Credentials.Path" }
        if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
        if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if ([string]::IsNullOrEmpty($vismaConnectTenantId)) { $missingConfiguration += "Authentication.VismaConnectTenantId" }
        if ([string]::IsNullOrEmpty($enableLogs)) { $missingConfiguration += "Logs.Enabled" }
        if ([string]::IsNullOrEmpty($logsPath)) { $missingConfiguration += "Logs.Path" }
        if ([string]::IsNullOrEmpty($businessTypeId)) { $missingConfiguration += "Upload.BusinessTypeId" }
        if ([string]::IsNullOrEmpty($contentDirectoryPath)) { $missingConfiguration += "Upload.Path" }
        if ([string]::IsNullOrEmpty($contentFilter)) { $missingConfiguration += "Upload.Filter" }
        if ([string]::IsNullOrEmpty($archivePath)) { $missingConfiguration += "Upload.ArchivePath" }
        if ([string]::IsNullOrEmpty($chunkSize)) { $missingConfiguration += "Upload.ChunkSize" }
   
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }
    
        $wrongConfiguration = @()
        if (-not [Validator]::IsPath($credentialsPath)) { $wrongConfiguration += "Credentials.Path" }
        if (-not [Validator]::IsUri($fileApiBaseUrl)) { $wrongConfiguration += "Services.FileApiBaseUrl" }
        if (-not [Validator]::IsUri($authenticationTokenApiBaseUrl)) { $wrongConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if (-not [Validator]::IsBool($enableLogs)) { $wrongConfiguration += "Logs.Enabled" }
        if (-not [Validator]::IsPath($logsPath)) { $wrongConfiguration += "Logs.Path" }
        if (-not [Validator]::IsPath($contentDirectoryPath)) { $wrongConfiguration += "Upload.Path" }
        if (-not [Validator]::IsPath($archivePath)) { $wrongConfiguration += "Upload.ArchivePath" }
        if ($chunkSize -gt $chunkSizeLimit) { $wrongConfiguration += "Chunk size ($($chunkSize)) cannot be bigger than $($chunkSizeLimit) bytes." }
        if ($chunkSize -lt 1) { $wrongConfiguration += "Chunk size ($($chunkSize)) cannot be smaller than 1 (Mbyte)." }


        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        $configuration = [Configuration]::new()
        $configuration.Credentials.Path = $credentialsPath
        $configuration.Services.FileApiBaseUrl = $fileApiBaseUrl
        $configuration.Services.AuthenticationTokenApiBaseUrl = $authenticationTokenApiBaseUrl
        $configuration.Credentials.TenantId = $vismaConnectTenantId
        $configuration.Logs.Enabled = [System.Convert]::ToBoolean($enableLogs)
        $configuration.Logs.Path = $logsPath
        $configuration.Upload.BusinessTypeId = $businessTypeId
        $configuration.Upload.Path = $contentDirectoryPath
        $configuration.Upload.Filter = $contentFilter
        $configuration.Upload.ArchivePath = $archivePath
        $configuration.Upload.ChunkSize = $chunkSize * 1024 * 1024 # convert to bytes

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
            $this._logger.LogInformation("Storage credential filePath doesn't exist. Creating it.")
            $this._logger.LogInformation("| Path: $($storagePath)")
            
            New-Item -ItemType Directory -Force -Path $storagePath
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
    hidden [long] $_fileSize
    hidden [long] $_fileBytesRead
    hidden [string] $_boundary
    hidden [string] $_businessTypeId
    hidden [long] $_chunkSize
    hidden [int] $_uploadDelay

    FileApiService(
        [Logger] $logger,
        [FileApiClient] $fileApiClient,
        [string] $businessTypeId,
        [long] $chunkSize
    ) {
        $this._logger = $logger
        $this._fileApiClient = $fileApiClient
        $this._boundary = "file_info"
        $this._businessTypeId = $businessTypeId
        $this._chunkSize = $chunkSize
        $this._uploadDelay = 0
    }

    [void] UploadAndArchiveFiles([string] $uploadPath, [string] $mask, [string] $archivePath) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Uploading files:")
        $this._logger.LogInformation("| Path: $($uploadPath)")
        $this._logger.LogInformation("| Mask: $($mask)")
    
        if (-not (Test-Path -Path $uploadPath -PathType Container)) {
            throw "Directory <$($uploadPath)> doesn't exist."
        }
    
        $filesToUploadInfo = Get-ChildItem -Path $uploadPath -Filter $mask

        $this._logger.LogInformation("$($filesToUploadInfo.Length) files found.")
        $this._logger.MonitorInformation("Uploading $($filesToUploadInfo.Length) files.")

        $uploadedFilesCount = 0
        foreach ($fullFilenameToUpload in $filesToUploadInfo.FullName) {
            $this.UploadFile($fullFilenameToUpload)
            [Helper]::ArchiveFile($archivePath, $fullFilenameToUpload, $this._logger)

            $uploadedFilesCount++
        }
    
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("All files were uploaded.")
        $this._logger.LogInformation("| Amount: $($uploadedFilesCount)")
    }

    hidden [void] UploadFile($filenameToUpload) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Uploading the file:")
        $this._logger.LogInformation("| File: $($(Split-Path -Path $filenameToUpload -Leaf))")
        $this._logger.LogInformation("| Business type: $($this._businessTypeId)")
        $this._logger.MonitorInformation("File $($(Split-Path -Path $filenameToUpload -Leaf)) is uploading")

        $this._logger.LogInformation("Uploading chunk #1.")

        $result = $this.UploadFirstRequest($filenameToUpload)
        $fileToken = $result.FileToken
        $chunkNumber = 1
        While (-not $result.Eof) {
            $this._logger.LogInformation("Uploading chunk #$($chunkNumber + 1).")

            $result = $this.UploadChunkRequest($fileToken, $filenameToUpload, $chunkNumber)
            $chunkNumber++
        }

        $this._logger.LogInformation("The file was uploaded.")
        $this._logger.MonitorInformation("File $($(Split-Path -Path $filenameToUpload -Leaf)) was uploaded successfully")
    }

    hidden [PSCustomObject] UploadFirstRequest([string] $filenameToUpload) {
        $this._fileSize = (Get-Item $filenameToUpload).Length
        $this._fileBytesRead = 0
        $filenameOnly = Split-Path -Path $filenameToUpload -Leaf

        $chunkNumber = 0
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $firstRequestData = $this.CreateFirstChunkRequest($filenameOnly, $result.ChunkPath)
        $response = $this.UploadAndRemoveChunk($firstRequestData, $filenameOnly, "multipart/related;boundary=$($this._boundary)", "", $chunkNumber, $result.Eof)
        $fileToken = $response.uploadToken
        
        return [PSCustomObject]@{
            FileToken = $fileToken
            Eof       = $result.Eof
        }
    }

    hidden [PSCustomObject] UploadChunkRequest([string] $fileToken, [string] $filenameToUpload, [long] $chunkNumber) {
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $this.UploadAndRemoveChunk($result.ChunkPath, $(Split-Path -Path $filenameToUpload -Leaf), "application/octet-stream", $fileToken, $chunkNumber, $result.Eof)

        return [PSCustomObject]@{
            Eof = $result.Eof
        }
    }

    hidden [string] CreateFirstChunkRequest([string] $filename, [string] $chunkPath) {
        $headerFilePath = ""
        $footerFilePath = ""
        try {
            $folderPath = $(Split-Path -Path $chunkPath)
            $contentFilename = $(Split-Path -Path $filename -Leaf)
            $createdFilePath = "$($folderPath)\$([Helper]::ConvertToUniqueFilename("multipart.bin"))"

            $headerFilename = [Helper]::ConvertToUniqueFilename("header.txt")
            $headerFilePath = "$($folderPath)\$($headerFilename)"
            $headerContent = "--$($this._boundary)`r`n" # Windows line breaks are required.
            $headerContent += "Content-Type: application/json; charset=UTF-8`r`n"
            $headerContent += "`r`n"
            $headerContent += "{`r`n`"name`":`"$($contentFilename)`",`r`n`"businesstypeid`":`"$($this._businessTypeId)`"`r`n}`r`n"
            $headerContent += "--$($this._boundary)`r`n`r`n"

            $footerFilename = [Helper]::ConvertToUniqueFilename("footer.txt")
            $footerFilePath = "$($folderPath)\$($footerFilename)"
            $footerContent = "`r`n--$($this._boundary)--"

            $script:temporaryResourcesPaths += Join-Path $folderPath $headerFilename
            $script:temporaryResourcesPaths += Join-Path $folderPath $footerFilename
            $script:temporaryResourcesPaths += $chunkPath
            $script:temporaryResourcesPaths += $createdFilePath

            New-Item -Path $folderPath -Name $headerFilename -Value $headerContent
            New-Item -Path $folderPath -Name $footerFilename -Value $footerContent

            cmd /c copy /b $headerFilePath + $chunkPath + $footerFilePath $createdFilePath

            return $createdFilePath
        }
        finally {
            if (Test-Path $headerFilePath) {
                Remove-Item -Force -Path $headerFilePath
            }
            if (Test-Path $footerFilePath) {
                Remove-Item -Force -Path $footerFilePath
            }
            if (Test-Path $chunkPath) {
                Remove-Item -Force -Path $chunkPath
            }
        }
    }

    hidden [PSCustomObject] CreateChunk([string] $contentFilePath, [long] $chunkSize, [long] $chunkNumber) {
        $folderPath = $(Split-Path -Path $contentFilePath)
        $createdChunkPath = "$($folderPath)\$([Helper]::ConvertToUniqueFilename("Chunk_$($chunkNumber).bin"))"
        [byte[]]$bytes = new-object Byte[] $chunkSize
        $fileStream = New-Object System.IO.FileStream($contentFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = New-Object System.IO.BinaryReader( $fileStream)
        $binaryReader.BaseStream.Seek($chunkNumber * $chunkSize, [System.IO.SeekOrigin]::Begin)
        $bytes = $binaryReader.ReadBytes($chunkSize) 
       
        $this._fileBytesRead += $bytes.Length
        [bool] $streamEof = 0
        if (($bytes.Length -lt $chunkSize) -or ($this._fileBytesRead -ge $this._fileSize)) {
            $streamEof = 1
        }

        $binaryReader.Dispose()

        # The way of encoding the bytes changed in the version 6.0.0. See the following link for more information:
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-7.3#parameters
        if ($global:PSVersionTable.PSVersion -ge "6.0.0") {
            Set-Content -Path $createdChunkPath -Value $bytes -AsByteStream
        }
        else {
            Set-Content -Path $createdChunkPath -Value $bytes -Encoding Byte
        }

        return [PSCustomObject]@{
            ChunkPath = $createdChunkPath
            Eof       = $streamEof
        }
    }

    hidden [PSCustomObject] UploadAndRemoveChunk([string] $filePath, [string] $originalFilename, [string] $contentType, [string] $token, [long] $chunkNumber, [bool] $close) {
        while ($true) {
            try {
                Start-Sleep -Milliseconds $this._uploadDelay

                $result = $this._fileApiClient.UploadFile($filePath, $contentType, $token, $chunkNumber, $close )

                if (-not [string]::IsNullOrEmpty($filePath) -and (Test-Path $filePath)) {
                    Remove-Item -Force -Path $filePath
                }

                return $result
            }
            catch {
                if ($_.Exception.Message.Contains("(429)")) {
                    $this._uploadDelay += 100

                    $waitSeconds = 60

                    $this._logger.LogInformation("Spike arrest detected: Setting uploadDelay to $($this._uploadDelay) ms.")
                    $this._logger.LogInformation("Waiting $($waitSeconds) seconds for spike arrest to clear")

                    Start-Sleep -Seconds $waitSeconds
                }
                else {
                    throw $_
                }
            }
        }

        throw "UploadFile aborted: should never come here"
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

    [PSCustomObject] UploadFile([string] $bodyPath, [string] $contentType, [string] $token, [long] $chunkNumber, [bool] $close) {
        $headers = $this._defaultHeaders
        if (-not [string]::IsNullOrEmpty($contentType)) {
            $headers["Content-Type"] = $contentType
        }
        $uri = "$($this.BaseUrl)/files"
        if (($chunkNumber -eq 0) -and $close) {
            $uri += "?uploadType=multipart"
        }
        else {
            $uri += "?uploadType=resumable"
        }
        if (-not [string]::IsNullOrEmpty($token)) {
            $uri += "&uploadToken=$($token)"
        }
        if ($chunkNumber -ne 0) {
            $uri += "&position=$($chunkNumber)"
        }
        if ($close -and ($chunkNumber -gt 0)) {
            $uri += "&close=true"
        }
        if ($chunkNumber -eq 0) {
            $response = Invoke-RestMethod `
                -Method "Post" `
                -Uri     $uri `
                -Headers $headers `
                -InFile "$($bodyPath)"
        }
        else {
            $response = Invoke-RestMethod `
                -Method "Put" `
                -Uri     $uri `
                -Headers $headers `
                -InFile "$($bodyPath)"
        }

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
    hidden [string] $_monPath
    hidden [string] $_upDown

Logger([bool] $storeLogs, [string] $logsDirectory, [string] $monFile, [string] $upDownLoad) {
    # this parameter is $true (store logs) or $false (do not store logs)
    $this._storeLogs = $storeLogs

    if ($this._storeLogs) {
        # detailed log file created per day
        $this._logPath = Join-Path $logsDirectory "download log - $(Get-Date -Format "yyyy-MM-dd").txt"
        # only 1 monitor file created
        $this._monPath = Join-Path $logsDirectory $monFile
        # signals a download or upload record (easy if you use the same the Monitor File for both upload and download)
        $this._upDown = $upDownLoad
    
        if (-not (Test-Path -Path $logsDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $logsDirectory -Force
        }
    }
}

    [void] LogRaw([string] $text) {
        Write-Host $text
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
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

    # Log an INFO record in the monitor log file
    [void] MonitorInformation([string] $text) {
        $text = $this.GetFormattedDate() + " {0,-10} [INFO]  {1}" -f "[$($this._upDown)]", $($text)

        if ($this._storeLogs) {
            $text | Out-File $this._monPath -Encoding utf8 -Append -Force
        }
    }

    # Log an ERROR record in the monitor log file
    [void] MonitorError([string] $text) {
        $text = $this.GetFormattedDate() + " {0,-10} [ERROR] {1}" -f "[$($this._upDown)]", $($text)

        if ($this._storeLogs) {
            $text | Out-File $this._monPath -Encoding utf8 -Append -Force
        }
    }

    # the date format preceding each log record
    [string] GetFormattedDate() {
        return Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    }
}

class Helper {
    static [string] RetrieveWindowsVersion() {
        if (!($env:OS).Contains("Windows")) {
            return $null
        }

        $WindowsInformation = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, OSArchitecture, Version
        return "$($WindowsInformation.Caption) ($($WindowsInformation.OSArchitecture)) $($WindowsInformation.Version)"
    }

    static [void] ArchiveFile([string] $archivePath, [string] $filename, [Logger] $logger) {
        if (-not $logger) {
            $logger = [Logger]::new($false, "")
        }

        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $archiveFilename = [Helper]::ConvertToUniqueFilename($filenameInfo.FullName)
        $archiveFilePath = Join-Path $archivePath $archiveFilename

        $logger.logInformation("----")
        $logger.LogInformation("Archiving file:")
        $logger.LogInformation("| Name: $($filenameInfo.Name)")
        $logger.LogInformation("| Destination path: $($archiveFilePath)")

        if (-not (Test-Path -Path $archivePath -PathType Container)) {
            $logger.logInformation("----")
            $logger.LogInformation("Archive path doesn't exist. Creating it.")
            $logger.LogInformation("| Path: $($archivePath)")

            New-Item -ItemType Directory -Force -Path $archivePath | Out-Null

            $logger.LogInformation("The archive path was created.")
        }

        try {
            Move-Item $filename -Destination $archiveFilePath
            $logger.logInformation("The file was archived.")
            $logger.MonitorInformation("File $($(Split-Path -Path $filename -Leaf)) was archived")
        }
        catch {
            $logger.LogError("The file was not archived.")
            $logger.MonitorError("File $($(Split-Path -Path $filename -Leaf)) could not be archived")
            throw $_
        }
    }

    static [string] ConvertToUniqueFilename([string] $filename) {
        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $filenameWithoutExtension = $filenameInfo.Name
        $fileExtension = $filenameInfo.Extension
        $timestamp = Get-Date -Format "yyyyMMddTHHmmssffffZ"
        
        $filePath = $filenameInfo.Path
        if ([string]::IsNullOrEmpty($filepath)) {
            $uniqueFilename = "$($filenameWithoutExtension)_$($timestamp)$($fileExtension)"
        }
        else {
            $uniqueFilename = "$($filePath)\\$($filenameWithoutExtension)_$($timestamp)$($fileExtension)"
        }
        return $uniqueFilename
    }

    static [FilenameInfo] GetFilenameInfo([string] $filename) {
        $filenameInfo = [FilenameInfo]::new()
        $filenameInfo.FullPath = $filename
        $filenameInfo.FullName = ""
        $filenameInfo.Name = ""
        $filenameInfo.Extension = ""
        $filenameInfo.Path = ""
        
        $splitPath = $filename -split "\\"
        if ($splitPath.Length -gt 1) {
            $filenameInfo.Path = $splitPath[0..($splitPath.Length - 2)] -Join "\"
            $filenameInfo.FullName = $splitPath[$splitPath.Length - 1]
            $filenameInfo.Name = $filenameInfo.FullName
        }
        else { 
            $filenameInfo.Name = $filename
            $filenameInfo.FullName = $filename
        }

        $splitFilename = $filenameInfo.FullName -split "\."
        if ($splitFilename.Length -gt 1) {
            $filenameInfo.Name = $splitFilename[0]
            $filenameInfo.Extension = ".$($splitFilename[-1])"
        }

        return $filenameInfo
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

        # Clean up all the temporary resources that weren't removed during the execution.
        $existingtemporaryResourcesPaths = $script:temporaryResourcesPaths | Where-Object { Test-Path $_ }
        if ($existingtemporaryResourcesPaths) {
            $logger.LogInformation("----")
            $logger.LogInformation("Deleting temporary resources:")

            foreach ($existingTemporaryResourcePath in $existingtemporaryResourcesPaths) {
                $logger.LogInformation("| Path: $($existingTemporaryResourcePath)")
                $logger.MonitorInformation("Resource $($existingTemporaryResourcePath) was deleted")

                Remove-Item -Force -Path $existingTemporaryResourcePath
            }
        }
        $script:temporaryResourcesPaths = @()

        $logger.LogInformation("----")
        $logger.LogInformation("End of the example.")

        $logger.MonitorInformation("Upload script ended")

        if ($finishWithError) {
            exit 1
        }
        else {
            exit
        }
    }

    static [PSCustomObject] GetDotNetFrameworkVersion()
    {
        [string]$ComputerName = $env:COMPUTERNAME

        $dotNet4Registry = 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
        $dotNet4Builds = @{
            '30319'  = @{ Version = [System.Version]'4.0'                                                     }
            '378389' = @{ Version = [System.Version]'4.5'                                                     }
            '378675' = @{ Version = [System.Version]'4.5.1'   ; Comment = '(8.1/2012R2)'                      }
            '378758' = @{ Version = [System.Version]'4.5.1'   ; Comment = '(8/7 SP1/Vista SP2)'               }
            '379893' = @{ Version = [System.Version]'4.5.2'                                                   }
            '380042' = @{ Version = [System.Version]'4.5'     ; Comment = 'and later with KB3168275 rollup'   }
            '393295' = @{ Version = [System.Version]'4.6'     ; Comment = '(Windows 10)'                      }
            '393297' = @{ Version = [System.Version]'4.6'     ; Comment = '(NON Windows 10)'                  }
            '394254' = @{ Version = [System.Version]'4.6.1'   ; Comment = '(Windows 10)'                      }
            '394271' = @{ Version = [System.Version]'4.6.1'   ; Comment = '(NON Windows 10)'                  }
            '394802' = @{ Version = [System.Version]'4.6.2'   ; Comment = '(Windows 10 Anniversary Update)'   }
            '394806' = @{ Version = [System.Version]'4.6.2'   ; Comment = '(NON Windows 10)'                  }
            '460798' = @{ Version = [System.Version]'4.7'     ; Comment = '(Windows 10 Creators Update)'      }
            '460805' = @{ Version = [System.Version]'4.7'     ; Comment = '(NON Windows 10)'                  }
            '461308' = @{ Version = [System.Version]'4.7.1'   ; Comment = '(Windows 10 Fall Creators Update)' }
            '461310' = @{ Version = [System.Version]'4.7.1'   ; Comment = '(NON Windows 10)'                  }
            '461808' = @{ Version = [System.Version]'4.7.2'   ;                                               }
            '461814' = @{ Version = [System.Version]'4.7.2'   ;                                               }
            '528040' = @{ Version = [System.Version]'4.8'     ;                                               }
            '528372' = @{ Version = [System.Version]'4.8'     ;                                               }
            '528449' = @{ Version = [System.Version]'4.8'     ;                                               }
            '528049' = @{ Version = [System.Version]'4.8'     ;                                               }
            '533320' = @{ Version = [System.Version]'4.8.1'   ;                                               }
            '533325' = @{ Version = [System.Version]'4.8.1'   ;                                               }
        }

        if($regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName))
        {
            if ($net4RegKey = $regKey.OpenSubKey("$dotNet4Registry"))
            {
                if(-not ($net4Release = $net4RegKey.GetValue('Release')))
                {
                    $net4Release = 30319
                }
                return New-Object -TypeName PSCustomObject -Property ([ordered]@{
                        ComputerName = $ComputerName
                        Build = $net4Release
                        Version = $dotNet4Builds["$net4Release"].Version
                        Comment = $dotNet4Builds["$net4Release"].Comment
                })
            }
        }
        return New-Object -TypeName PSCustomObject -Property (@{
                        ComputerName = $ComputerName
                        Build = "Unknown"
                        Version = "Unknown"
                        Comment = "Unknown"
                })
    }

}

#endregion Helper classes

#region Models

class Configuration {
    $Credentials = [ConfigurationSectionCredentials]::new()
    $Services = [ConfigurationSectionServices]::new()
    $Logs = [ConfigurationSectionLogs]::new()
    $Upload = [ConfigurationSectionUpload]::new()
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
    [string] $MonitorFile
}

class ConfigurationSectionUpload {
    [string] $BusinessTypeId
    [string] $Path
    [string] $Filter
    [string] $ArchivePath
    [long]   $ChunkSize
}

class FileInfo {
    [string] $Id
    [string] $Name
    [long] $Size
}

class FilenameInfo {
    [string] $Name
    [string] $Extension
    [string] $FullName
    [string] $Path
    [string] $FullPath
}

class Credentials {
    [string] $ClientId
    [string] $ClientSecret
    [string] $TenantId
}

#endregion Models

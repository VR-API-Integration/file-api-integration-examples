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

$logger.LogInformation("=============================================================")
$logger.LogInformation("File API integration example: Upload files from a directory.")
$logger.LogInformation("                              Supports files > 100Mb")
$logger.LogInformation("=============================================================")
$logger.LogInformation("(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')")

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
$fileApiService = [FileApiService]::new($logger, $fileApiClient, $config.Upload.BusinessTypeId, $config.Upload.ChunkSize)

#region Upload Directory contents

Get-ChildItem -Path $config.Upload.Path -Filter $config.Upload.Filter | ForEach-Object -Process {

    $filenameToUpload = $_.FullName

    try {
        $fileApiService.UploadFile($filenameToUpload)
    }
    catch {
        [Helper]::EndProgramWithError($_, "Failure uploading file $($filenameToUpload).", $logger)
    }

    try {
        $archivedFile = [Helper]::ArchiveFile($config.Upload.ArchivePath, $_.FullName, $logger)
    }
    catch {
        [Helper]::EndProgramWithError($_, "Failure archiving file to $($archivedFile).", $logger)
    }
}

#endregion Upload Directory contents

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

    [void] UploadFile($filenameToUpload) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Uploading the file.")
        $this._logger.LogInformation("| File: $($(Split-Path -Path $filenameToUpload -Leaf))")
        $this._logger.LogInformation("| Business type: $($this._businessTypeId)")

        $result = $this.UploadFirstRequest($filenameToUpload)
        $fileToken = $result.FileToken
        $chunkNumber = 1
        While ( -not $result.Eof ) {
            $this._logger.LogInformation("Uploading Chunk #$($chunkNumber + 1).")
            $result = $this.UploadChunkRequest($fileToken, $filenameToUpload, $chunkNumber)
            $chunkNumber += 1
        }
        $this._logger.LogInformation("File $($(Split-Path -Path $filenameToUpload -Leaf)) uploaded.")
    }

    [PSCustomObject] UploadFirstRequest([string] $filenameToUpload) {
        $this._fileSize = (Get-Item $filenameToUpload).Length
        $this._fileBytesRead = 0
        $filenameOnly = Split-Path -Path $filenameToUpload -Leaf
        $chunkNumber = 0
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $FirstRequestData = $this.CreateFirstRequestToUpload($filenameOnly, $result.ChunkPath)
        $response = $this.UploadFile($FirstRequestData, $filenameOnly, "multipart/related;boundary=$($this._boundary)", "", $chunkNumber, $result.Eof)
        $fileToken = $response.uploadToken
        
        return [PSCustomObject]@{
            FileToken = $fileToken
            Eof       = $result.Eof
        }
    }

    [PSCustomObject] UploadChunkRequest([string] $fileToken, [string] $filenameToUpload, [long] $chunkNumber) {
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $this.UploadFile($result.ChunkPath, $(Split-Path -Path $filenameToUpload -Leaf), "application/octet-stream", $fileToken, $chunkNumber, $result.Eof)

        return [PSCustomObject]@{
            Eof = $result.Eof
        }
    }

    [string] CreateFirstRequestToUpload([string] $filename, [string] $chunkPath) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Creating first request with the file $($filename) to upload.")
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

            New-Item -Path $folderPath -Name $headerFilename -Value $headerContent
            New-Item -Path $folderPath -Name $footerFilename -Value $footerContent

            cmd /c copy /b $headerFilePath + $chunkPath + $footerFilePath $createdFilePath
            $this._logger.LogInformation("File created.")
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

    [PSCustomObject] CreateChunk([string] $contentFilePath, [long] $chunkSize, [long] $chunkNumber) {
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

        Set-Content -Path $createdChunkPath -Value $bytes -Encoding Byte

        return [PSCustomObject]@{
            ChunkPath = $createdChunkPath
            Eof       = $streamEof
        }
    }

    [PSCustomObject] UploadFile([string] $filePath, [string] $originalFilename, [string] $contentType, [string] $token, [long] $chunkNumber, [bool] $close) {
        while (1 -eq 1) {
            try {
                Start-Sleep -Milliseconds $this._uploadDelay

                $result = $this._fileApiClient.UploadFile($filePath, $contentType, $token, $chunkNumber, $close )

                if (-not [string]::IsNullOrEmpty($filePath) -and (Test-Path $filePath)) {
                    Remove-Item -Force -Path $filePath
                }

                return $result
            }
            catch {
                if ( $_.Exception.Message.Contains("(429)")) {
                    $this._uploadDelay += 100
                    $this._logger.LogInformation("Spike arrest detected: Setting uploadDelay to $($this._uploadDelay) msec.")
                    $this._logger.LogInformation("Waiting 60 seconds for spike arrest to clear")
                    Start-Sleep -Seconds 60
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

    Logger([bool] $storeLogs, [string] $logsDirectory) {
        $this._storeLogs = $storeLogs

        if ($this._storeLogs) {
            $this._logPath = Join-Path $logsDirectory "upload log - $([Helper]::NewUtcDate("yyyy-MM-dd")).txt"

            if (-not (Test-Path -Path $logsDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $logsDirectory -Force
            }
        }
    }

    [void] LogInformation([string] $text) {
        $text = "$([Helper]::NewUtcDate("yy/MM/dd HH:mm:ss")) [Information] $($text)"

        Write-Host $text
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }

    [void] LogError([string] $text) {
        $text = "$([Helper]::NewUtcDate("yy/MM/dd HH:mm:ss")) [Error] $($text)"

        Write-Host $text -ForegroundColor "Red"
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }
}

class Helper {
    static [string] ArchiveFile([string] $archivePath, [string] $filename, [Logger] $logger) {
        if (-not $logger) {
            $logger = [Logger]::new($false, "")
        }

        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $uniqueArchiveFilename = [Helper]::ConvertToUniqueFilename($filenameInfo.FullName)
        $archivePath = Join-Path $archivePath $uniqueArchiveFilename

        $logger.logInformation("----")
        $logger.LogInformation("Archiving file <$($filenameInfo.Name)> to <$($archivePath)>.")

        try {
            Move-Item $filename -Destination $archivePath
            $logger.logInformation("File archived.")
        }
        catch {
            $logger.LogError("The file was not archived.")
            throw $_
        }
        return $archivePath
    }

    static [string] ConvertToUniqueFilename([string] $filename) {
        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $filenameWithoutExtension = $filenameInfo.Name
        $fileExtension = $filenameInfo.Extension
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        
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

    static [string] NewUtcDate([string] $format) {
        return (Get-Date).ToUniversalTime().ToString($format)
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

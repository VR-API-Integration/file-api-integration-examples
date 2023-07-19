# This example shows how to upload a file. 
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Full filePath of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload\config.xml). Default value: set in the code.'
    )]
    [string] $_configPath,

    [Alias("RenewCredentials")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Boolean. $true if you want to renew your credentials. $false otherwise'
    )]
    [bool] $_renewCredentials = $false
)

$ErrorActionPreference = "Stop"

# The default value of this parameter is set here because $PSScriptRoot is empty if used directly in Param() through PowerShell ISE.
if (-not $_configPath) {
    $_configPath = "$($PSScriptRoot)\config.xml"
}

Write-Host "========================================================="
Write-Host "File API example: Upload files from a directory."
Write-Host "                  Supports files > 100Mb"
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

#region Configuration

[ConfigurationManager] $configurationManager = [ConfigurationManager]::new()

try {
    $config = $configurationManager.Get($_configPath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.")
}

#endregion Configuration

#region Retrieve/Create credentials

$credentialsManager = [CredentialsManager]::new($config.Credentials.Path)
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
    [Helper]::EndProgramWithError($_, "Failure retrieving the credentials.")
}

#endregion Retrieve/Create credentials

#region Retrieve authentication token

$authenticationApiClient = [AuthenticationApiClient]::new($config.Services.AuthenticationTokenApiBaseUrl)
$authenticationApiService = [AuthenticationApiService]::new($authenticationApiClient)

try {
    $token = $authenticationApiService.NewToken($credentials.ClientId, $credentials.ClientSecret, $credentials.TenantId)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.")
}

#endregion Retrieve authentication token

$fileApiClient = [FileApiClient]::new($config.Services.FileApiBaseUrl, $token)
$fileApiService = [FileApiService]::new($fileApiClient, $config.Upload.BusinessTypeId, $config.Upload.ChunkSize)

#region Upload Directory contents

Get-ChildItem -Path $config.Upload.Path -Filter $config.Upload.Filter | ForEach-Object -Process {

    $filenameToUpload = $_.FullName

    try {
        $fileApiService.UploadFile($filenameToUpload)
    }
    catch {
        [Helper]::EndProgramWithError($_, "Failure uploading file $($filenameToUpload).")
    }

    try {
        $archivedFile =  [Helper]::ArchiveFile($config.Upload.ArchivePath, $_.FullName)
    }
    catch {
        [Helper]::EndProgramWithError($_, "Failure archiving file to $($archivedFile).")
    }
}



#endregion Upload Directory contents

[Helper]::EndProgram()

# -------- END OF THE PROGRAM --------
# Below there are classes and models to help the readability of the program

#region Helper classes

class ConfigurationManager {
    [Configuration] Get($configPath) {
        Write-Host "----"
        Write-Host "Retrieving the configuration."
    
        if (-not (Test-Path $configPath -PathType Leaf)) {
            throw "Configuration not found.`r`n| Path: $($configPath)"
        }
        
        $configDocument = [xml](Get-Content $configPath)
        $config = $configDocument.Configuration

        $credentialsPath = $config.Credentials.Path
    
        $fileApiBaseUrl = $config.Services.FileApiBaseUrl
        $authenticationTokenApiBaseUrl = $config.Services.AuthenticationTokenApiBaseUrl
        $vismaConnectTenantId = $config.Authentication.VismaConnectTenantId

        $businessTypeId = $config.Upload.BusinessTypeId
        $contentDirectoryPath = $config.Upload.Path
        $contentFilter = $config.Upload.Filter
        $chunkSize = [long] $config.Upload.ChunkSize 
        $chunkSizeLimit = [long] 100

        $archivePath = $config.Upload.ArchivePath
    
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($credentialsPath)) { $missingConfiguration += "Credentials.Path" }
        if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
        if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if ([string]::IsNullOrEmpty($vismaConnectTenantId)) { $missingConfiguration += "Authentication.VismaConnectTenantId" }
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
        if (-not [Validator]::IsPath($contentDirectoryPath)) { $wrongConfiguration += "Upload.Path" }
        if (-not [Validator]::IsPath($archivePath)) { $wrongConfiguration += "Upload.ArchivePath" }
        if($chunkSize -gt $chunkSizeLimit) { $wrongConfiguration += "Chunk size ($($chunkSize)) cannot be bigger than $($chunkSizeLimit) bytes."}
        if($chunkSize -lt 1){$wrongConfiguration += "Chunk size ($($chunkSize)) cannot be smaller than 1 (Mbyte)."}


        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        $configuration = [Configuration]::new()
        $configuration.Credentials.Path = $credentialsPath
        $configuration.Credentials.TenantId = $vismaConnectTenantId
        $configuration.Services.FileApiBaseUrl = $fileApiBaseUrl
        $configuration.Services.AuthenticationTokenApiBaseUrl = $authenticationTokenApiBaseUrl
        $configuration.Upload.BusinessTypeId = $businessTypeId
        $configuration.Upload.Path = $contentDirectoryPath
        $configuration.Upload.Filter = $contentFilter
        $configuration.Upload.ArchivePath = $archivePath
        $configuration.Upload.ChunkSize = $chunkSize * 1024 * 1024 #convert to bytes

        Write-Host "Configuration retrieved."

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
    hidden [string] $_credentialsPath

    CredentialsManager([string] $storagePath) {
        $this._credentialsPath = $storagePath
    }

    [void] CreateNew() {
        $storagePath = Split-Path $this._credentialsPath
        
        Write-Host "----"
        Write-Host "Saving your credentials."
        Write-Host "| Path: $($this._credentialsPath)"

        if (-not (Test-Path -Path $storagePath -PathType Container)) {
            Write-Host "----"
            Write-Host "Storage credential filePath doesn't exist. Creating it."
            Write-Host "| Path: $($storagePath)"
            
            New-Item -ItemType Directory -Force -Path $storagePath
        }

        Write-Host "Enter your credentials."
        $clientId = Read-Host -Prompt '| Client ID'
        $clientSecret = Read-Host -Prompt '| Client secret' -AsSecureString

        [PSCredential]::new($clientId, $clientSecret) | Export-CliXml -Path $this._credentialsPath

        Write-Host "----"
        Write-Host "Credentials saved."
    }

    [Credentials] Retrieve() {
        Write-Host "----"
        Write-Host "Retrieving your credentials."
        Write-Host "| Path: $($this._credentialsPath)"

        if (-not (Test-Path -Path $this._credentialsPath -PathType Leaf)) {
            Write-Host "----"
            Write-Host "Credentials not found."
            Write-Host "| Path: $($this._credentialsPath)"
            
            return $null
        }

        $credentialsStorage = Import-CliXml -Path $this._credentialsPath

        $credentials = [Credentials]::new()
        $credentials.ClientId = $credentialsStorage.GetNetworkCredential().UserName
        $credentials.ClientSecret = $credentialsStorage.GetNetworkCredential().Password

        Write-Host "Credentials retrieved."

        return $credentials
    }
}

class FileApiService {
    hidden [FileApiClient] $_fileApiClient
    hidden [long] $_fileSize
    hidden [long] $_fileBytesRead
    hidden [string] $_boundary
    hidden [string] $_businessTypeId
    hidden [long] $_chunkSize
    hidden [int] $_uploadDelay

    FileApiService(
        [FileApiClient] $fileApiClient,
        [string] $businessTypeId,
        [long] $chunkSize
    ) {
        $this._fileApiClient = $fileApiClient
        $this._boundary = "file_info"
        $this._businessTypeId = $businessTypeId
        $this._chunkSize = $chunkSize
        $this._uploadDelay = 0
    }

    [void] UploadFile($filenameToUpload){
        Write-Host "----"
        Write-Host "Uploading the file."
        Write-Host "| File: $($(Split-Path -Path $filenameToUpload -Leaf))"
        Write-Host "| Business type: $($this._businessTypeId)"

        $result = $this.UploadFirstRequest($filenameToUpload)
        $fileToken = $result.FileToken
        $chunkNumber = 1
        While( -not $result.Eof ) {
            Write-Host "Uploading Chunk #$($chunkNumber + 1)."
            $result = $this.UploadChunkRequest($fileToken, $filenameToUpload, $chunkNumber)
            $chunkNumber += 1
        }
        Write-Host "File $($(Split-Path -Path $filenameToUpload -Leaf)) uploaded."
    }

    [PSCustomObject] UploadFirstRequest([string] $filenameToUpload){
        $this._fileSize = (Get-Item $filenameToUpload).Length
        $this._fileBytesRead = 0
        $filenameOnly = Split-Path -Path $filenameToUpload -Leaf
        $chunkNumber = 0
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $FirstRequestData = $this.CreateFirstRequestToUpload($filenameOnly, $result.ChunkPath)
        $response = $this.UploadFile($FirstRequestData, $filenameOnly, "multipart/related;boundary=$($this._boundary)", "", $chunkNumber, $result.Eof)
        $fileToken =   $response.uploadToken
        
        return [PSCustomObject]@{
            FileToken = $fileToken
            Eof = $result.Eof
            }
    }

    [PSCustomObject] UploadChunkRequest([string] $fileToken, [string] $filenameToUpload, [long] $chunkNumber){
        $result = $this.CreateChunk($filenameToUpload, $this._chunkSize, $chunkNumber)
        $response = $this.UploadFile($result.ChunkPath, $(Split-Path -Path $filenameToUpload -Leaf), "application/octet-stream", $fileToken, $chunkNumber, $result.Eof)

        return [PSCustomObject]@{
            Eof = $result.Eof
            }
    }

    [string] CreateFirstRequestToUpload([string] $filename, [string] $chunkPath) {
        Write-Host "----"
        Write-Host "Creating first request with the file $($filename) to upload."
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
            Write-Host "File created."
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

    [PSCustomObject] CreateChunk([string] $contentFilePath, [long] $chunkSize, [long] $chunkNumber){
        $folderPath = $(Split-Path -Path $contentFilePath)
        $contentFilename = $(Split-Path -Path $contentFilePath -Leaf)
        $createdChunkPath = "$($folderPath)\$([Helper]::ConvertToUniqueFilename("Chunk_$($chunkNumber).bin"))"
        [byte[]]$bytes = new-object Byte[] $chunkSize
        $fileStream = New-Object System.IO.FileStream($contentFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = New-Object System.IO.BinaryReader( $fileStream)
        $pos = $binaryReader.BaseStream.Seek($chunkNumber * $chunkSize, [System.IO.SeekOrigin]::Begin)
        $bytes = $binaryReader.ReadBytes($chunkSize) 
       
        $this._fileBytesRead += $bytes.Length
        [bool] $streamEof = 0
        if(($bytes.Length -lt $chunkSize) -or ($this._fileBytesRead -ge $this._fileSize)) {
            $streamEof = 1
        }

        $binaryReader.Dispose()  

        Set-Content -Path $createdChunkPath -Value $bytes -Encoding Byte

        return [PSCustomObject]@{
            ChunkPath = $createdChunkPath
            Eof = $streamEof
            }
    }

    [PSCustomObject] UploadFile([string] $filePath, [string] $originalFilename, [string] $contentType, [string] $token, [long] $chunkNumber, [bool] $close) {
    
        while(1 -eq 1) {
            try{
                Start-Sleep -Milliseconds $this._uploadDelay

                $result = $this._fileApiClient.UploadFile($filePath, $contentType, $token, $chunkNumber, $close )

                if (-not [string]::IsNullOrEmpty($filePath) -and (Test-Path $filePath)) {
                    Remove-Item -Force -Path $filePath
                }

                return $result
            }
            catch{
                if( $_.Exception.Message.Contains("(429)")){
                    $this._uploadDelay += 100
                    Write-Host "Spike arrest detected: Setting uploadDelay to $($this._uploadDelay) msec."
                    Write-Host "Waiting 60 seconds for spike arrest to clear"
                    Start-Sleep -Seconds 60
                }
                else {
                    throw "$($_)"
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
        if(-not [string]::IsNullOrEmpty($contentType)){
            $headers["Content-Type"] = $contentType
        }
        $uri = "$($this.BaseUrl)/files"
        if(($chunkNumber -eq 0) -and $close) {
            $uri += "?uploadType=multipart"
        }
        else {
            $uri += "?uploadType=resumable"
        }
        if(-not [string]::IsNullOrEmpty($token)){
            $uri += "&uploadToken=$($token)"
        }
        if($chunkNumber -ne 0){
         $uri += "&position=$($chunkNumber)"
        }
        if($close -and ($chunkNumber -gt 0)) {
            $uri += "&close=true"
        }
        if($chunkNumber -eq 0){
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
    hidden [AuthenticationApiClient] $_authenticationApiClient

    AuthenticationApiService([AuthenticationApiClient] $authenticationApiClient) {
        $this._authenticationApiClient = $authenticationApiClient
    }

    [string] NewToken([string] $clientId, [string] $clientSecret, [string] $tenantId) {
        Write-Host "----"
        Write-Host "Retrieving the authentication token."

        $response = $this._authenticationApiClient.NewToken($clientId, $clientSecret, $tenantId)
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

class Helper {
    static [string] ArchiveFile([string] $archivePath, [string] $filename) {
        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $uniqueArchiveFilename = [Helper]::ConvertToUniqueFilename($filenameInfo.FullName)
        $archivePath = Join-Path $($archivePath) $($uniqueArchiveFilename)
        try { 
            Move-Item $filename -Destination $archivePath
            Write-Host "File archived to ($($archivePath))."
        }
        catch {
            Write-Host "File NOT archived."
            throw $_
        }
        return $archivePath
    }

    static [string] ConvertToUniqueFilename([string] $filename) {
        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $filePath = $filenameInfo.Path
        $filenameWithoutExtension = $filenameInfo.Name
        $fileExtension = $filenameInfo.Extension
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        if([string]::IsNullOrEmpty($filepath)){
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
        if($splitFilename.Length -gt 1) {
            $filenameInfo.Name = $splitFilename[0]
            $filenameInfo.Extension = ".$($splitFilename[-1])"
        }

        return $filenameInfo
    }

    static [void] EndProgram() {
        [Helper]::FinishProgram($false)
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

        [Helper]::FinishProgram($true)
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

#endregion Helper classes

#region Models

class Configuration {
    $Credentials = [ConfigurationSectionCredentials]::new()
    $Services = [ConfigurationSectionServices]::new()
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

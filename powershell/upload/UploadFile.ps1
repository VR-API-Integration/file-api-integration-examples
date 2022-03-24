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
Write-Host "File API example: Upload a file."
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
$credentialsService = [CredentialsService]::new($credentialsManager)

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
    $token = $authenticationApiService.NewToken($credentials.ClientId, $credentials.ClientSecret)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the authentication token.")
}

#endregion Retrieve authentication token

$fileApiClient = [FileApiClient]::new($config.Services.FileApiBaseUrl, $token)
$fileApiService = [FileApiService]::new($fileApiClient, $config.Upload.TenantId, $config.Upload.BusinessTypeId)

#region Upload file

try {
    $createdFilePath = $fileApiService.CreateFileToUpload($config.Upload.Path) 
    $fileApiService.UploadFile($createdFilePath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure uploading the file.")
}

#endregion Upload file

[Helper]::EndProgram()

# -------- END OF THE PROGRAM --------
# Below there are classes and models to help the readability of the program

#region Helper classes

class ConfigurationManager {
    [Configuration] Get($configPath) {
        Write-Host "----"
        Write-Host "Retrieving the configuration."
    
        if (-not (Test-Path $configPath -PathType Leaf)) {
            throw "Configuration not found.`r`n| Path: $configPath"
        }
        
        $configDocument = [xml](Get-Content $configPath)
        $config = $configDocument.Configuration
    
        $credentialsPath = $config.Credentials.Path
    
        $fileApiBaseUrl = $config.Services.FileApiBaseUrl
        $authenticationTokenApiBaseUrl = $config.Services.AuthenticationTokenApiBaseUrl
        
        $tenantId = $config.Upload.TenantId
        $businessTypeId = $config.Upload.BusinessTypeId
        $contentFilePath = $config.Upload.Path
    
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($credentialsPath)) { $missingConfiguration += "Credentials.Path" }
        if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
        if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if ([string]::IsNullOrEmpty($tenantId)) { $missingConfiguration += "Upload.TenantId" }
        if ([string]::IsNullOrEmpty($businessTypeId)) { $missingConfiguration += "Upload.BusinessTypeId" }
        if ([string]::IsNullOrEmpty($contentFilePath)) { $missingConfiguration += "Upload.Path" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }
    
        $wrongConfiguration = @()
        if (-not [Validator]::IsPath($credentialsPath)) { $wrongConfiguration += "Credentials.Path" }
        if (-not [Validator]::IsUri($fileApiBaseUrl)) { $wrongConfiguration += "Services.FileApiBaseUrl" }
        if (-not [Validator]::IsUri($authenticationTokenApiBaseUrl)) { $wrongConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if (-not [Validator]::IsPath($contentFilePath)) { $wrongConfiguration += "Upload.Path" }

        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        $configuration = [Configuration]::new()
        $configuration.Credentials.Path = $credentialsPath
        $configuration.Services.FileApiBaseUrl = $fileApiBaseUrl
        $configuration.Services.AuthenticationTokenApiBaseUrl = $authenticationTokenApiBaseUrl
        $configuration.Upload.TenantId = $tenantId
        $configuration.Upload.BusinessTypeId = $businessTypeId
        $configuration.Upload.Path = $contentFilePath

        Write-Host "Configuration retrieved."

        return $configuration
    }
}

class CredentialsService {
    hidden [CredentialsManager] $_credentialsManager

    CredentialsService ([CredentialsManager] $manager) {
        $this._credentialsManager = $manager
    }

    [Credentials] Retrieve() {        
        $credentials = $this._credentialsManager.Retrieve()
        if ($null -eq $credentials) {
            $credentials = $this.CreateNew()
            return $credentials
        }
    
        return $credentials
    }

    [Credentials] CreateNew() {
        $this._credentialsManager.CreateNew()
        $credentials = $this._credentialsManager.Retrieve()

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
    hidden [string] $_tenantId
    hidden [long] $_uploadSizeLimit
    hidden [string] $_boundary
    hidden [string] $_businessTypeId

    FileApiService(
        [FileApiClient] $fileApiClient,
        [string] $tenantId,
        [string] $businessTypeId
    ) {
        $this._fileApiClient = $fileApiClient
        $this._tenantId = $tenantId
        $this._boundary = "file_info"
        $this._businessTypeId = $businessTypeId

        # API supports files up to 100 megabytes
        $this._uploadSizeLimit = 100 * 1024 * 1024
    }

    [string] CreateFileToUpload([string] $contentFilePath) {
        Write-Host "---"
        Write-Host "Creating a bundle with the file $($contentFilePath) to upload."
        $headerFilePath = ""
        $footerFilePath = ""
        try {
            $folderPath = $(Split-Path -Path $contentFilePath)
            $contentFilename = $(Split-Path -Path $contentFilePath -Leaf)
            $createdFilePath = "$($folderPath)\$([Helper]::ConverToUniqueFilename("multipart.bin"))"

            $headerFilename = [Helper]::ConverToUniqueFilename("header.txt")
            $headerFilePath = "$($folderPath)\$($headerFilename)"
            $headerContent = "--$($this._boundary)`r`n" # Windows line breaks are required.
            $headerContent += "Content-Type: application/json; charset=UTF-8`r`n"
            $headerContent += "`r`n"
            $headerContent += "{`r`n`"name`":`"$($contentFilename)`",`r`n`"businesstypeid`":`"$($this._businessTypeId)`"`r`n}`r`n"
            $headerContent += "--$($this._boundary)`r`n`r`n"

            $footerFilename = [Helper]::ConverToUniqueFilename("footer.txt")
            $footerFilePath = "$($folderPath)\$($footerFilename)"
            $footerContent = "`r`n--$($this._boundary)--"

            New-Item -Path $folderPath -Name $headerFilename -Value $headerContent
            New-Item -Path $folderPath -Name $footerFilename -Value $footerContent

            cmd /c copy /b $headerFilePath + $contentFilePath + $footerFilePath $createdFilePath
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
        }
    }

    [void] UploadFile([string] $filePath) {
        if ((Get-Item $filePath).Length -gt $this._uploadSizeLimit) {
            Write-Host "---" -ForegroundColor "Red"
            Write-Host "Cannot upload files bigger $($this._uploadSizeLimit) bytes." -ForegroundColor "Red"
            return
        }
        Write-Host "---"
        Write-Host "Uploading the file."
        $this._fileApiClient.UploadFile($this._tenantId, $filePath, $this._boundary)
        
        Write-Host "File uploaded."
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

    [PSCustomObject] UploadFile([string] $tenantId, [string] $multipartContentFilePath, [string] $boundary) {
        $headers = $this._defaultHeaders
        $headers["x-raet-tenant-id"] = $tenantId
        $headers["Content-Type"] = "multipart/related;boundary=$($boundary)"
        try {
            $response = Invoke-RestMethod `
                -Method "Post" `
                -Uri "$($this.BaseUrl)/files?uploadType=multipart" `
                -Headers $headers `
                -InFile "$($multipartContentFilePath)"

            return $response
        }

        finally {
            if (Test-Path $multipartContentFilePath) {
                Remove-Item -Force -Path $multipartContentFilePath
            }
        }
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
    static [string] ConverToUniqueFilename([string] $filename) {
        $filenameInfo = [Helper]::GetFilenameInfo($filename)
        $filenameWithoutExtension = $filenameInfo.Name
        $fileExtension = $filenameInfo.Extension
        $timestamp = Get-Date -Format FileDateTimeUniversal
    
        $uniqueFilename = "$($filenameWithoutExtension)_$($timestamp)$($fileExtension)"
        return $uniqueFilename
    }

    static [FilenameInfo] GetFilenameInfo([string] $filename) {
        $filenameInfo = [FilenameInfo]::new()
        $filenameInfo.Name = $filename
        $filenameInfo.Extension = ""
        
        $splitFilename = $filename -split "\."
        if ($splitFilename.Length -gt 1) {
            $filenameInfo.Name = $splitFilename[0..($splitFilename.Length - 2)] -Join "."
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
}

class ConfigurationSectionServices {
    [string] $FileApiBaseUrl
    [string] $AuthenticationTokenApiBaseUrl
}

class ConfigurationSectionUpload {
    [string] $TenantId
    [string] $BusinessTypeId
    [string] $Path
}

class FileInfo {
    [string] $Id
    [string] $Name
    [long] $Size
}

class FilenameInfo {
    [string] $Name
    [string] $Extension
}

class Credentials {
    [string] $ClientId
    [string] $ClientSecret
}

#endregion Models

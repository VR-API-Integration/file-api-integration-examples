# This example shows how to download all the files specified in a filter.
# Authors: Visma - Transporters Team

[CmdletBinding()]
Param(
    [Alias("ConfigPath")]
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Full path of the configuration (e.g. C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\config.xml). Default value: set in the code.'
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
Write-Host "File API example: Download files specified in a filter."
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
$fileApiService = [FileApiService]::new($fileApiClient, $config.Download.TempFolder, $config.Download.Role, 200, $config.Download.ChunkSize)

#region List files

try {
    $filesInfo = $fileApiService.GetFilesInfo($config.Download.Filter)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the files.")
}

if ($filesInfo.Count -eq 0) {
    [Helper]::EndProgram()
}

#endregion List files

#region Download files

try {
    $fileApiService.DownloadFiles($filesInfo, $config.Download.Path, $config.Download.EnsureUniqueNames)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure downloading the files.")
}

#endregion Download files

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

        $role = $Config.Download.Role
        $downloadPath = $config.Download.Path
        $tempFolder = $config.Download.TempFolder
        $ensureUniqueNames = $config.Download.EnsureUniqueNames
        $chunkSize = [long] $config.Download.ChunkSize 
        $chunkSizeLimit = [long] 100
        $filter = $config.Download.Filter
    
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($credentialsPath)) { $missingConfiguration += "Credentials.Path" }
        if ([string]::IsNullOrEmpty($fileApiBaseUrl)) { $missingConfiguration += "Services.FileApiBaseUrl" }
        if ([string]::IsNullOrEmpty($authenticationTokenApiBaseUrl)) { $missingConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if ([string]::IsNullOrEmpty($vismaConnectTenantId)) { $missingConfiguration += "Authentication.VismaConnectTenantId" }
        if ([string]::IsNullOrEmpty($role)) { $missingConfiguration += "Download.Role" }
        if ([string]::IsNullOrEmpty($downloadPath)) { $missingConfiguration += "Download.Path" }
        if ([string]::IsNullOrEmpty($tempFolder)) { $missingConfiguration += "Download.TempFolder" }
        if ([string]::IsNullOrEmpty($ensureUniqueNames)) { $missingConfiguration += "Download.EnsureUniqueNames" }
        if ([string]::IsNullOrEmpty($chunkSize)) { $missingConfiguration += "Download.ChunkSize" }

        if ($null -eq $filter) { $missingConfiguration += "Download.Filter" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }
    
        $wrongConfiguration = @()
        if (-not [Validator]::IsPath($credentialsPath)) { $wrongConfiguration += "Credentials.Path does not exist" }
        if (-not [Validator]::IsUri($fileApiBaseUrl)) { $wrongConfiguration += "Services.FileApiBaseUrl" }
        if (-not [Validator]::IsUri($authenticationTokenApiBaseUrl)) { $wrongConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if (-not [Validator]::IsPath($downloadPath)) { $wrongConfiguration += "Download.Path does not exist" }
        if (-not [Validator]::IsPath($tempFolder)) { $wrongConfiguration += "Download.TempFolder does not exist" }
        if (-not [Validator]::IsBool($ensureUniqueNames)) { $wrongConfiguration += "Download.EnsureUniqueNames" }
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
        $configuration.Download.Role = $role
        $configuration.Download.Path = $downloadPath
        $configuration.Download.TempFolder = $tempFolder
        $configuration.Download.EnsureUniqueNames = [System.Convert]::ToBoolean($ensureUniqueNames)
        $configuration.Download.ChunkSize = $chunkSize * 1024 * 1024 #convert to bytes
        $configuration.Download.Filter = $filter
    
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
            Write-Host "Storage credential path doesn't exist. Creating it."
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
    hidden [string] $_tempFolder
    hidden [string] $_role
    hidden [int] $_waitTimeBetweenCallsMS
    hidden [long] $_chunkSize

    FileApiService(
        [FileApiClient] $fileApiClient,
        [string] $tempFolder,
        [string] $role,
        [int] $waitTimeBetweenCallsMS,
        [long] $chunkSize
    ) {
        $this._fileApiClient = $fileApiClient
        $this._tempFolder = $tempFolder
        $this._role = $role
        $this._waitTimeBetweenCallsMS = $waitTimeBetweenCallsMS
        $this._chunkSize = $chunkSize
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
        $downloadedFilesCount = 0
        $failedFiles = @()
        foreach ($fileInfo in $filesInfo) {
            Write-Host "----"
            Write-Host "Downloading file $($downloadedFilesCount + 1)/$($filesInfo.Count)."
            Write-Host "| ID  : $($fileInfo.Id)"
            Write-Host "| Name: $($fileInfo.Name)"
            Write-Host "| Size: $($fileInfo.Size)"

            if (($ensureUniqueNames -eq $true) -and (Test-Path "$($path)\$($fileInfo.Name)" -PathType Leaf)) {
                Write-Host "There is already a file with the same name in the download path."

                $fileInfo.Name = [Helper]::ConvertToUniqueFileName($fileInfo.Name)

                Write-Host "| New name: $($fileInfo.Name)"
            }
            try{
                $this.DownloadFile($this._role, $fileInfo, $path)
                $downloadedFilesCount++
                Write-Host "The file $($fileinfo.Name) was downloaded."
            } catch {
                $failedFiles += $fileinfo
                Write-Host "The file $($fileinfo.Name) failed."
            }
        
            Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS
        }

        Write-Host "----"
        if( $failedFiles.Length -eq 0) {
            Write-Host "All files were downloaded."
        } else {
            Write-Host "$($downloadedFilesCount) of $($filesInfo.Length) files were downloaded"
            Write-Host "The following files failed ($($failedFiles.Length)):"
            foreach( $fileinfo in $failedFiles){
                Write-Host "$($fileinfo.Name)"
            }
        }
        Write-Host "| Path: $($path)"
    }

    [void] DownloadFile([string] $role, [FileInfo] $fileInfo, [string] $downloadPath) {
        # Download the file in the temp folder
        # Move it when succesfully downloaded

        $destinationFilename = $fileinfo.Name
        $tempFilePath = "$($this._tempFolder)\$($destinationFilename)"

        if($fileinfo.Size -le $this._chunkSize) {
            $result = $this._fileApiClient.DownloadFileInOneGo($this._role, $fileInfo, $tempFilePath)
        } else {
            [long] $fileBytesRead = 0
            [long] $chunkNumber = 0
            [int] $totalchunks = $fileinfo.Size / $this._chunkSize

            Write-Host "Downloading Headers"
            $result = $this._fileApiClient.DownloadHeader($this._role, $fileInfo, $this._tempFolder)

            while ($fileBytesRead -lt $fileinfo.Size){
                Write-Host "Downloading Chunk $($chunkNumber + 1) / $($totalchunks)"

                $bytes = $this.DownloadChunk($this._role, $fileInfo, $this._chunkSize, $chunkNumber)
                Add-Content -Path "$tempFilePath" -Value $bytes -Encoding Byte 

                $fileBytesRead += $bytes.Length
                $chunkNumber += 1
            }
        }
        Move-Item -Path $tempFilePath -Destination $downloadPath -Force
    }

    [byte[]] DownloadChunk([string] $role, [FileInfo] $fileInfo, [int32] $chunkSize, [int]$chunkNumber) {
        [int]$maxretry = 10
        [int]$retry = 0

        while(1 -eq 1) {
            try{
                Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS

                $bytes = $this._fileApiClient.DownloadChunk($role, $fileInfo, $chunkSize, $chunkNumber)

                return $bytes
            }
            catch{
                if( $_.Exception.Message -match "(429)"){
                    $this._waitTimeBetweenCallsMS += 100
                    Write-Host "Spike arrest detected: Setting requestDelay to $($this._waitTimeBetweenCallsMS) msec."
                    Write-Host "Waiting 60 seconds for spike arrest to clear"
                    Start-Sleep -Seconds 60
                }
                else {
                    if($_.Exception.Message -match "(5..)") {
                        $retry += 1
                        if( $retry -le $maxretry) {
                            Write-Host "Downloading chunk $($chunkNumber): retry $($retry)"
                        } else { 
                            throw "$($_)"
                        }
                    }
                    else {
                        throw "$($_)"
                    }
                }
            }
        }

        throw "UploadFile aborted: should never come here"

    }

}

class FileApiClient {
    [string] $BaseUrl
    
    hidden [PSCustomObject] $_defaultHeaders
    hidden [string] $_authorization

    FileApiClient (
        [string] $baseUrl,
        [string] $token
    ) {
        $this.BaseUrl = $baseUrl
        $this._defaultHeaders = @{
            "Authorization"    = "Bearer $($token)";
            }
        $this._authorization = "Bearer $($token)";
    }

    [PSCustomObject] ListFiles([string] $role, [int] $pageIndex, [int] $pageSize, [string] $filter) {
        $headers = $this._defaultHeaders

        $uri = "$($this.BaseUrl)/files?role=$($role)&pageIndex=$($pageIndex)&pageSize=$($pageSize)&`$filter=$($filter)&`$orderBy=uploadDate asc"
        Write-Host "Uri: $($uri)"

        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files?role=$($role)&pageIndex=$($pageIndex)&pageSize=$($pageSize)&`$filter=$($filter)&`$orderBy=uploadDate asc" `
            -Headers $headers

        return $response
    }


    [PSCustomObject] DownloadFileInOneGo([string] $role, [FileInfo] $fileInfo, [string] $downloadPath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)" `
            -Headers $headers `
            -OutFile "$($downloadPath)\$($fileInfo.Name)"

        return $response
    }

    [PSCustomObject] DownloadHeader([string] $role, [FileInfo] $fileInfo, [string] $downloadPath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        $response = Invoke-RestMethod `
            -Method "Head" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)" `
            -Headers $headers `
            -OutFile "$($downloadPath)\$($fileInfo.Name)"

        return $response
    }

    [byte[]] DownloadChunk([string] $role, [FileInfo] $fileInfo, [int32] $chunkSize, [int]$chunkNumber) {
 #       $headers = $this._defaultHeaders
 #       $headers.Accept = "application/octet-stream"

#        $headers.Range = "bytes=$($rangeStart)-$($rangeEnd)";

        $uri = "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)"

        $request = [System.Net.WebRequest]::Create($uri)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", $this._defaultHeaders["Authorization"])
        $request.Accept = "application/octet-stream"

        # add range header
        $rangeStart = [long] ($chunkNumber * $chunkSize)
        $rangeEnd = [long] $rangeStart + $chunkSize - 1
        $request.AddRange("bytes", $rangeStart, $rangeEnd)

        $reader = New-Object System.IO.BinaryReader($request.GetResponse().GetResponseStream())
        $response = $reader.ReadBytes($chunksize)

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
            $result = Test-Path $testParameter
            return $result
        }
        catch {
            return $false
        }
    }
}

class Helper {
    static [string] ConvertToUniqueFileName([string] $fileName) {
        $fileNameInfo = [Helper]::GetFileNameInfo($fileName)
        $fileNameWithoutExtension = $fileNameInfo.Name
        $fileExtension = $fileNameInfo.Extension
        $timestamp = Get-Date -Format FileDateTime
    
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

class ConfigurationSectionDownload {
    [string] $Role
    [string] $Path
    [string] $TempFolder
    [bool] $EnsureUniqueNames
    [long] $ChunkSize
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

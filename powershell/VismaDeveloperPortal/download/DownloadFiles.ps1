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
$scriptMajorVersion = 1
$scriptMinorVersion = 23

# The default value of this parameter is set here because $PSScriptRoot is empty if used directly in Param() through PowerShell ISE.
if (-not $_configPath) {
    $_configPath = "$($PSScriptRoot)\config.xml"
}

#region Log configuration
#try reading <Logs> configuration first so that we are able to log other possible errors in the configuration

try {
    $logConfig = [ConfigurationManager]::GetLogConfiguration($_configPath)
}
catch {
    [Helper]::EndProgramWithError($_, "Failure retrieving the logger configuration. Tip: see the README.MD to check the format of the parameters.", $null)
}

[Logger] $logger = [Logger]::new($logConfig.Enabled, $logConfig.Path, $logConfig.MonitorFile, "DOWNLOAD")

#endregion Log configuration

$logger.LogRaw("")
$logger.LogInformation("==============================================")
$logger.LogInformation("File API integration example: Download files.")
$logger.LogInformation("==============================================")
$logger.LogInformation("(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')")
$logger.LogInformation("Versions:")
$logger.LogInformation("| Script     : $($scriptMajorVersion).$($scriptMinorVersion)")
$logger.LogInformation("| PowerShell : $($global:PSVersionTable.PSVersion)")
$logger.LogInformation("| Windows    : $(if (($env:OS).Contains("Windows")) { [Helper]::RetrieveWindowsVersion() } else { "Unknown OS system detected" })")
$logger.LogInformation("| NET version: $([Helper]::GetDotNetFrameworkVersion().Version)")




$logger.MonitorInformation("Download script started")

#region Rest of the configuration

try {
    $config = [ConfigurationManager]::GetConfiguration($_configPath)
}
catch {
    $logger.MonitorError("Failure reading the configuration file")
    [Helper]::EndProgramWithError($_, "Failure retrieving the configuration. Tip: see the README.MD to check the format of the parameters.", $logger)
}

#endregion Rest of the configuration

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

$fileApiClient = [FileApiClient]::new($config.Services.FileApiBaseUrl, $token)
$fileApiService = [FileApiService]::new($logger, $fileApiClient, $config.Download.Role, 200, $config.Download.ChunkSize)

#region List files

try {
    $filesInfo = $fileApiService.GetFilesInfo($config.Download.Filter)

    if($filesInfo.Count -gt 0){
        $logger.MonitorInformation("$($filesInfo.Count) file(s) ready for download with filter : $($config.Download.Filter)" )
    } else {
        $logger.MonitorInformation("No files to download with filter : $($config.Download.Filter)")
    }
}
catch {
    $logger.MonitorError("Failure retrieving the filelist from File Api")
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
    $logger.MonitorError("Failure downloading file(s) : $($_)")
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
        $monitorFile = $config.Logs.MonitorFile

        # check for missing Logs configuration options
        $missingConfiguration = @()
        if ([string]::IsNullOrEmpty($enableLogs)) { $missingConfiguration += "Logs.Enabled" }
        if ([string]::IsNullOrEmpty($logsPath)) { $missingConfiguration += "Logs.Path" }
        if ([string]::IsNullOrEmpty($monitorFile)) { $missingConfiguration += "Logs.MonitorFile" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }

        #check for invalid Logs configuration options
        $wrongConfiguration = @()
        if (-not [Validator]::IsBool($enableLogs)) { $wrongConfiguration += "Logs.Enabled" }
        if (-not [Validator]::IsPath($logsPath)) { $wrongConfiguration += "Logs.Path" }
    
        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        #set configuration parameters
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
        
        #read config.xml
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
        $chunkSize = [int] $config.Download.ChunkSize 
        $chunkSizeLimit = [int] 100
        $filter = $config.Download.Filter
    
        #check for missing configuration options
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
        if ([string]::IsNullOrEmpty($chunkSize)) { $missingConfiguration += "Download.ChunkSize" }

        if ($null -eq $filter) { $missingConfiguration += "Download.Filter" }
    
        if ($missingConfiguration.Count -gt 0) {
            throw "Missing parameters: $($missingConfiguration -Join ", ")"
        }
    
        #check for invalid configuration options
        $wrongConfiguration = @()
        if (-not [Validator]::IsPath($credentialsPath)) { $wrongConfiguration += "Credentials.Path is not a valid path" }
        if (-not [Validator]::IsUri($fileApiBaseUrl)) { $wrongConfiguration += "Services.FileApiBaseUrl is not a valid Url" }
        if (-not [Validator]::IsUri($authenticationTokenApiBaseUrl)) { $wrongConfiguration += "Services.AuthenticationTokenApiBaseUrl" }
        if (-not [Validator]::IsBool($enableLogs)) { $wrongConfiguration += "Logs.Enabled is not a boolean" }
        if (-not [Validator]::IsPath($logsPath)) { $wrongConfiguration += "Logs.Path is not a valid path" }
        if (-not [Validator]::IsPath($downloadPath)) { $wrongConfiguration += "Download.Path is not a valid path" }
        if (-not [Validator]::IsBool($ensureUniqueNames)) { $wrongConfiguration += "Download.EnsureUniqueNames is not a boolean" }
        if($chunkSize -gt $chunkSizeLimit) { $wrongConfiguration += "Chunk size ($($chunkSize)) cannot be bigger than $($chunkSizeLimit) MB"}
        if($chunkSize -lt 1){$wrongConfiguration += "Chunk size ($($chunkSize)) cannot be smaller than 1 (MB)."}
    
        if ($wrongConfiguration.Count -gt 0) {
            throw "Wrong configured parameters: $($wrongConfiguration -Join ", ")"
        }

        #set configuration parameters
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
        $configuration.Download.ChunkSize = $chunkSize * 1024 * 1024 #convert to bytes
        $configuration.Download.Filter = $filter

        return $configuration
    }
}

class CredentialsService {
    hidden [CredentialsManager] $_credentialsManager
    hidden [string] $_tenantId

    CredentialsService ([CredentialsManager] $manager, [string] $tenantId) {
        $this._credentialsManager = $manager

        #tenantid is VismaConnect Tenantid
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

        #asking credentials via the console
        $this._logger.LogInformation("Enter your credentials.")
        $clientId = Read-Host -Prompt '| Client ID'
        $clientSecret = Read-Host -Prompt '| Client secret' -AsSecureString

        #save secure credentials xml file
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

        #read credentials from secure xml file
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
    hidden [long] $_chunkSize
    hidden [string] $_partial

    FileApiService(
        [Logger] $logger,
        [FileApiClient] $fileApiClient,
        [string] $role,
        [int] $waitTimeBetweenCallsMS,
        [long] $chunkSize
    ) {
        $this._logger = $logger
        $this._fileApiClient = $fileApiClient
        $this._role = $role # subscriber or provider
        $this._waitTimeBetweenCallsMS = $waitTimeBetweenCallsMS # delay between requests to avoid spike arrest
        $this._chunkSize = $chunkSize
        $this._partial = ".partial" # file extension while downloading file
    }

    # get filelist from FileAPI with the specified filter
    [FileInfo[]] GetFilesInfo([string] $filter) {
        $this._logger.LogInformation("----")
        $this._logger.LogInformation("Retrieving list of files.")
        if ($filter) {
            $this._logger.LogInformation("| Filter: $($filter)")
        }

        $pageIndex = 0
        $pageSize = 21
        $isLastPage = $false
        $filesInfo = [FileInfo[]] @()

        # retrieve (possible) multiple pages
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
        $failedFiles = @()  # maintain a list of failed files for logging

        # download each file in the list
        foreach ($fileInfo in $filesInfo) {
            $this._logger.LogInformation("----")
            $this._logger.LogInformation("Downloading file $($downloadedFilesCount + 1 + $failedFiles.Count)/$($filesInfo.Count).")
            $this._logger.LogInformation("| ID  : $($fileInfo.Id)")
            $this._logger.LogInformation("| Name: $($fileInfo.Name)")
            $this._logger.LogInformation("| Size: $($fileInfo.Size)")

            # if EnsureUniqueNames is true in config then make sure downloaded file is (made) unique
            if (($ensureUniqueNames -eq $true) -and (Test-Path "$($path)\$($fileInfo.Name)" -PathType Leaf)) {
                $this._logger.LogInformation("There is already a file with the same name in the download path.")

                $oldFileName = $fileInfo.Name
                $fileInfo.Name = [Helper]::ConverToUniqueFileName($fileInfo.Name)

                $this._logger.LogInformation("| New name: $($fileInfo.Name)")
                $this._logger.MonitorInformation("File already exists ($($oldFileName)). New download filename $($fileInfo.Name)")
            }

            try{
                $this._logger.MonitorInformation("File $($fileInfo.Name) is downloading.")

                $this.DownloadFile($this._role, $fileInfo, $path, $ensureUniqueNames)
                $downloadedFilesCount++
                
                $this._logger.LogInformation("The file $($fileInfo.Name) was downloaded successfully.")
                $this._logger.MonitorInformation("File $($fileInfo.Name) was downloaded successfully.")
            } catch {
                $failedFiles += $fileinfo
                $this._logger.LogError("The file $($fileInfo.Name) failed.")
                $this._logger.LogError("Error: $($_)")
                $this._logger.MonitorError("Failed download $($fileInfo.Name) : $($_)")
            }
        }

        $this._logger.LogInformation("----")

        # log summary
        if($failedFiles.Count -eq 0) {
            $this._logger.LogInformation("All files were downloaded.")
        } else {
            $this._logger.LogInformation("$($downloadedFilesCount) of $($filesInfo.Count) files were downloaded")
            $this._logger.LogInformation("The following files failed ($($failedFiles.Count)):")
            foreach($fileinfo in $failedFiles){
                $this._logger.LogInformation("$($fileinfo.Name)")

                $partialFileName = "$($path)\$($fileinfo.Name)$($this._partial)"
                if(Test-Path -Path $partialFileName -PathType Leaf) {
                    Remove-Item -Path $partialFileName -Force
                }
            }
        }
        $this._logger.LogInformation("| Path: $($path)")
    }

    [void] DownloadFile([string] $role, [FileInfo] $fileInfo, [string] $downloadPath, [bool] $ensureUniqueNames) {
        # Download the file with a .partial extension
        # Rename it when succesfully downloaded

        $destFileName = "$($downloadPath)\$($fileInfo.Name)"
        $tempFileName = "$($destFileName)$($this._partial)"

        # if the file is smaller than the ChunkSize --> download it in 1 request.
        if($fileInfo.Size -le $this._chunkSize) {
            try {
                $filestream = New-Object IO.FileStream $tempFileName ,'Create','Write','Read'

                $bytes = $this.DownloadFileInOneGo($this._role, $fileInfo, $tempFileName)

                $filestream.Write($bytes, 0, $bytes.Length)
            } catch{
                throw "$($_)"
            }
            finally {
                $filestream.Close()
            }
        } else {
            # download the file in multiple chunks
            [long] $fileBytesRead = 0
            [long] $chunkNumber = 0
            [int] $totalchunks = [math]::ceiling($fileInfo.Size / $this._chunkSize)

            $this._logger.LogInformation("Downloading Headers")
            $this._fileApiClient.DownloadHeader($this._role, $fileInfo, $this._tempFolder)

            $filestream = New-Object IO.FileStream $tempFileName ,'Append','Write','Read'
            try {
                # download chunks until all bytes are read
                while ($fileBytesRead -lt $fileInfo.Size){
                    $this._logger.LogInformation("Downloading Chunk $($chunkNumber + 1) / $($totalchunks)")

                    $bytes = $this.DownloadChunk($this._role, $fileInfo, $this._chunkSize, $chunkNumber)

                    $filestream.Write($bytes, 0, $bytes.Length)

                    $fileBytesRead += $bytes.Length
                    $chunkNumber += 1
                }
            } catch{
                throw "$($_)"
            }
            finally {
                $filestream.Close()
            }
        }
        # download complete - remove the .partial extension
        if(($ensureUniqueNames -eq $false) -and (Test-Path "$($destFileName)" -PathType Leaf)) {
            $this._logger.LogInformation("Overwriting file $($fileinfo.Name) because EnsureUniqueNames in config.xml is 'false'")
            $this._logger.MonitorInformation("Overwriting file $($fileinfo.Name) because EnsureUniqueNames in config.xml is 'false'")
        } 
        Move-Item -Path $tempFileName -Destination $destFileName -Force
    }

    [byte[]] DownloadFileInOneGo([string] $role, [FileInfo] $fileInfo, [string] $downloadFilePath) {
        [int]$maxretry = 10
        [int]$retry = 0

        while($true) {
            try{
                Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS

                $bytes = $this._fileApiClient.DownloadFileInOneGo([string] $role, [FileInfo] $fileInfo, [string] $downloadFilePath)
                
                return $bytes
            }
            catch{
                # when download fails due to spike arrest
                # increase delay to try avoid spike arrest for next requests
                # retry the download
                if($_.Exception.Message -match "\(429\)"){
                    $this._waitTimeBetweenCallsMS += 100
                    $this._logger.LogInformation("Spike arrest detected: Setting requestDelay to $($this._waitTimeBetweenCallsMS) msec.")
                    $this._logger.LogInformation("Waiting 60 seconds for spike arrest to clear")
                    Start-Sleep -Seconds 60
                }
                else {
                    # when download fails due to server error 5xx retry download max $maxretry (10) times
                    if($_.Exception.Message -match "\(5..\)") {
                        $retry += 1
                        if($retry -le $maxretry) {
                            $this._logger.LogInformation("Downloading file $($fileInfo.Name): retry $($retry)")
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
        throw "DownloadFileInOneGo aborted: should never come here"
    }

    [byte[]] DownloadChunk([string] $role, [FileInfo] $fileInfo, [int32] $chunkSize, [int]$chunkNumber) {
        [int]$maxretry = 10
        [int]$retry = 0

        while($true) {
            try{
                Start-Sleep -Milliseconds $this._waitTimeBetweenCallsMS

                $bytes = $this._fileApiClient.DownloadChunk($role, $fileInfo, $chunkSize, $chunkNumber)

                return $bytes
            }
            catch{
                # when download fails due to spike arrest
                # increase delay to try avoid spike arrest for next requests
                # retry the chunk download
                if($_.Exception.Message -match "\(429\)"){
                    $this._waitTimeBetweenCallsMS += 100

                    # wait 60 secs for spike arrest to clear
                    $waitSeconds = 60

                    $this._logger.LogInformation("Spike arrest detected: Setting requestDelay to $($this._waitTimeBetweenCallsMS) msec.")
                    $this._logger.LogInformation("Waiting $($waitSeconds) seconds for spike arrest to clear")
                    Start-Sleep -Seconds $waitSeconds
                }
                else {
                    # when download fails due to server error 5xx retry download max $maxretry (10) times
                    if($_.Exception.Message -match "\(5..\)") {
                        $retry += 1
                        if($retry -le $maxretry) {
                            $this._logger.LogInformation("Downloading chunk $($chunkNumber): retry $($retry)")
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

        throw "DownloadChunk aborted: should never come here"
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

    # list the available files in the File Api that conform to the filter
    [PSCustomObject] ListFiles([string] $role, [int] $pageIndex, [int] $pageSize, [string] $filter) {
        $headers = $this._defaultHeaders

        $response = Invoke-RestMethod `
            -Method "Get" `
            -Uri "$($this.BaseUrl)/files?role=$($role)&pageIndex=$($pageIndex)&pageSize=$($pageSize)&`$filter=$($filter)&`$orderBy=uploadDate asc" `
            -Headers $headers

        return $response
    }

    # download the file in 1 request
     [byte[]] DownloadFileInOneGo([string] $role, [FileInfo] $fileInfo, [string] $downloadFilePath) {
        $uri = "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)"

        # create request and the proper headers
        $request = [System.Net.WebRequest]::Create($uri)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", $this._defaultHeaders["Authorization"])
        $request.Accept = "application/octet-stream"

        # download the bytes into a BinaryReader
        $downloadStream = $request.GetResponse().GetResponseStream()
        $reader = New-Object System.IO.BinaryReader($downloadStream)
        $response = [byte[]] @()
        try {
            $response = $reader.ReadBytes($fileInfo.Size)
        } finally {
            $reader.Close()
        }

        return $response
    }

    [PSCustomObject] DownloadHeader([string] $role, [FileInfo] $fileInfo, [string] $downloadFilePath) {
        $headers = $this._defaultHeaders
        $headers.Accept = "application/octet-stream"

        $response = Invoke-RestMethod `
            -Method "Head" `
            -Uri "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)" `
            -Headers $headers `
            -OutFile "$($downloadFilePath)"

        return $response
    }

    # download a chunk
    # this method is not using the Invoke-RestMethod because there we can not add Range header (Powershell bug)
    [byte[]] DownloadChunk([string] $role, [FileInfo] $fileInfo, [int32] $chunkSize, [int]$chunkNumber) {
        $uri = "$($this.BaseUrl)/files/$($fileInfo.Id)?role=$($role)"

        # create request and the proper headers
        $request = [System.Net.WebRequest]::Create($uri)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", $this._defaultHeaders["Authorization"])
        $request.Accept = "application/octet-stream"

        # add range header (select which chunk/bytes to download)
        $rangeStart = [long] ($chunkNumber * $chunkSize)
        $rangeEnd = [long] $rangeStart + $chunkSize - 1
        $request.AddRange("bytes", $rangeStart, $rangeEnd)

        # download the bytes into a BinaryReader
        $downloadStream = $request.GetResponse().GetResponseStream()
        $reader = New-Object System.IO.BinaryReader($downloadStream)
        $response = [byte[]] @()
        try {
            $response = $reader.ReadBytes($chunksize)
        } finally {
            $reader.Close()
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

    # request a new access token
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

     # Create and execute the request to get a new access token
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

# helper class to validate parameter types
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
        }
        catch {
            return $false
        }
        return $result
    }
}

# class containing the Log functions
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

    # Log Raw text in detail log (without any formatting)
    [void] LogRaw([string] $text) {
        Write-Host $text
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }

    # Log an INFO record in the detailed log file
    [void] LogInformation([string] $text) {
        $text = $this.GetFormattedDate() + " [Information] $($text)"
        
        Write-Host $text
        if ($this._storeLogs) {
            $text | Out-File $this._logPath -Encoding utf8 -Append -Force
        }
    }

    # Log an Error record in the detailed log file
    [void] LogError([string] $text) {
        $text = $this.GetFormattedDate() + " [Error] $($text)"

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

    # make filename unique by adding a timestamp to the end of the filename keeping the extension
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
            $logger = [Logger]::new($false, "", "", "")
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
            $logger = [Logger]::new($false, "", "", "")
        }

        $logger.LogInformation("----")
        $logger.LogInformation("End of the example.")

        $logger.MonitorInformation("Download script ended")

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
    [string] $MonitorFile
}

class ConfigurationSectionDownload {
    [string] $Role
    [string] $Path
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

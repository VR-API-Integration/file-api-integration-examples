# This example shows how to download all the files specified in a filter

Write-Host "========================================================="
Write-Host "File API example: Download files specified in a filter."
Write-Host "========================================================="

Write-Host "(you can stop the script at any moment by pressing the buttons 'CTRL'+'C')"

#region Helpers

function Get-FileNameInfo_FileAPIHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName
    )

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

function ConvertTo-UniqueName_FileAPIHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName
    )

    $fileNameInfo = Get-FileNameInfo_FileAPIHelper $fileName
    $fileNameWithoutExtension = $fileNameInfo.Name
    $fileExtension = $fileNameInfo.Extension
    $timestamp = Get-Date -Format FileDateTimeUniversal

    $uniqueFileName = "$($fileNameWithoutExtension) - $($timestamp)$($fileExtension)"
    return $uniqueFileName
}

class DownloadChunkManager {
    [long]$ChunkStart
    [long]$ChunkEnd

    hidden [string] $_fileApiBaseUrl
    hidden [string] $_fileApiDownloadUrl
    hidden [string] $_fileId
    hidden [long] $_fileSize
    hidden [long] $_chunkSize
    hidden [string] $_fullDownloadPath
    hidden [string] $_role
    hidden [string] $_tenantId
    hidden [string] $_token

    hidden [long] $_byteReadCount
    hidden [long] $_bufferSize
    # hidden [string[]] $_downloadHeaders
    hidden [PSCustomObject] $_downloadHeaders
    hidden [PSCustomObject] $_downloadBody

    hidden [bool] $_isFirstRequest
    hidden [string] $_chunksUniqueIdentifier
    hidden [int] $_chunkCount

    DownloadChunkManager(
        [string] $fileApiBaseUrl,
        [string] $fileId,
        [long] $fileSize,
        [long] $chunkSize,
        [string] $fullDownloadPath,
        [string] $role,
        [string] $tenantId,
        [string] $token
    ) {
        $this._fileApiBaseUrl = $fileApiBaseUrl
        $this._fileId = $fileId
        $this._fileSize = $fileSize
        $this._chunkSize = $chunksize
        $this._fullDownloadPath = $fullDownloadPath
        $this._role = $role
        $this._tenantId = $tenantId
        $this._token = $token

        $this.StartValues()
    }

    [void] Download() {
        # XXX Check what happens if the path doesn't exist.
        # XXX I think it would be better to name the files .tmp and change the extension after the file is downloaded.
        $streamWriter = [System.IO.StreamWriter]::new($this._fullDownloadPath)

        while (-not $this.HasFinished()) {
            $response = $this.NextChunk()

            $streamReader = [System.IO.StreamReader]::new($response.GetResponseStream())
            # $streamReader = [System.IO.StreamReader]::new($response.GetResponseStream(), [System.Text.Encoding]::Default, $true)
            $buffer = [char[]]::new($this._bufferSize)
    
            while ($bytesRead = $streamReader.Read($buffer, 0, $buffer.Length)) {
                $streamWriter.Write($buffer, 0, $bytesRead) # XXX Check what happens if the path doesn't exist.
                $streamWriter.Flush()
            }
    
            $streamReader.Dispose()
        }

        $streamWriter.Dispose()
    }

    [System.Net.WebResponse] NextChunk() {
        $request = [System.Net.WebRequest]::Create($this._fileApiDownloadUrl)
        $request.Method = "GET"
        $request.Headers.Add("x-raet-tenant-id", $this._tenantId)
        $request.Headers.Add("Authorization", "Bearer $($this._token)")

        $request.Accept = "application/octet-stream"
        $request.AddRange("bytes", $this.ChunkStart, $this.ChunkEnd)

        $response = $request.GetResponse()

        $this.UpdateValues()
        return $response
    }

    [bool] HasFinished() {
        return $this._byteReadCount -ge ($this._fileSize - 1)
    }

    [void] StartValues() {
        $this._fileApiDownloadUrl = "$($this._fileApiBaseUrl)/files/$($this._fileId)?role=$($this._role)"

        $this._chunkCount = 0
        $this.ChunkStart = 0
        $this.ChunkEnd = $this.ChunkStart + $this._chunkSize - 1

        $this._bufferSize = 1024 # Put this in the config.xml. This is the memory that the script will use, so it affects the users.
        
        $this._isFirstRequest = $true
        $this._chunksUniqueIdentifier = ".$(New-Guid).tmp"
        $this._byteReadCount = 0
    }

    hidden [void] UpdateValues() {
        $this._chunkCount++
        $this._byteReadCount += $this.ChunkEnd - $this.ChunkStart + 1
        $this.ChunkStart = $this.ChunkEnd + 1

        if (($this.ChunkEnd + $this._chunkSize) -ge $this._fileSize) {
            $this.ChunkEnd = $this._fileSize - 1
        }
        else {
            $this.ChunkEnd = $this.ChunkEnd + $this._chunkSize
        }
    }
}

#endregion

#region Program

#region Configuration

# XXX
# $configPath = "$($PSScriptRoot)\config.xml"
$configPath = "C:\Users\AlbertoInf\Inbox\PBI FTaaS Improve curl examples\config.xml"
[xml]$configDocument = Get-Content $configPath
$config = $configDocument.Configuration

$clientId = $config.Credentials.ApiKey
$clientSecret = $config.Credentials.SecretKey
$tenantId = $config.TenantId
$listFilter = $config.List.Filter

$role = $Config.Download.Role
$downloadPath = $config.Download.Path
$ensureUniqueNames = $config.Download.EnsureUniqueNames
$maxChunkSize = ([long]$config.Download.MaxChunkSizeMB) * 1024 * 1024
# $maxChunkSize = 30 # XXX

# $authTokenApiBaseUrl = "https://api.raet.com/authentication"
# $fileApiBaseUrl = "https://api.raet.com/mft/v1.0"
# $authTokenApiBaseUrl = "https://api-test.raet.com/authentication"
$fileApiBaseUrl = "https://api-test.raet.com/mft/v1.0"

#endregion

#region Retrieve_authentication_token

Write-Host "Retrieving the authentication token..."

# $authHeaders = @{
#     "Content-Type"  = "application/x-www-form-urlencoded";
#     "Cache-Control" = "no-cache";
# }
# $authBody = @{
#     "grant_type"    = "client_credentials";
#     "client_id"     = $clientId;
#     "client_secret" = $clientSecret;
# }

# $authTokenResponse = Invoke-RestMethod -Method "Post" -Uri "$($authTokenApiBaseUrl)/token" -Headers $authHeaders -Body $authBody
# $token = $authTokenResponse.access_token

# XXX
$token = $config.XXXToken

Write-Host "Authentication token retrieved."

#endregion

#region List_files

Write-Host "Calling the 'list' endpoint..."

# $listHeaders = @{
#     "x-raet-tenant-id" = $tenantId;
#     "Authorization"    = "Bearer $($token)";
# }
# $listBody = @{
#     '$filter' = $listFilter;
#     "role"    = $role
# }

# $listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files" -Headers $listHeaders -Body $listBody
# # $randomBinFiles = $content.links | where {$_.innerHTML -like 'random*'} | select href
# $filesToDownload = @()
# foreach ($fileData in $listResponse.data) {
#     $filesToDownload += @{
#         Id   = $fileData.fileId
#         Name = $fileData.fileName
#         Size = $fileData.fileSize
#     }
# }

# $filesToDownload = @(
#     @{
#         Id   = "c5d7438e-5c29-47e7-b518-01e5a39d6711"
#         Name = "sandbox_test_file.txt"
#         Size = 33
#     }
#     # @{
#     #     Id   = "d92ffb21-7938-488b-a405-bcbc9e0a9696"
#     #     Name = "sandbox_test_file.xml"
#     #     Size = 107
#     # }
# )

# $filesToDownload = @(
#     # @{
#     #     Id   = "177bfedb-1cf9-4d51-9450-0663e190c906"
#     #     Name = "testFile.txt"
#     #     Size = 8388608
#     # },
#     @{
#         Id   = "ee42afe3-e95f-4e66-ab70-505d2926fdc5"
#         Name = "testFile-small.txt"
#         Size = 38
#     }
# )

$filesToDownload = @(
    # ,@{
    #     Id   = "10527477-3400-4d91-9db9-556225ad885c"
    #     Name = "File_8M.txt"
    #     Size = 8388733
    # }
    # ,@{
    #     Id   = "84f3b847-a62c-4ea8-8945-cbc7d1556bc9"
    #     Name = "File_110M.txt"
    #     Size = 112639601
    # }
    # ,@{
    #     Id   = "e2ff4e01-8996-4458-a427-c952f94c95b9"
    #     Name = "small file.txt"
    #     Size = 3
    # }
    # This one doesn't work.
    # ,@{
    #     Id   = "638bba65-1bb8-4860-b666-397136eb5e58"
    #     Name = "File_zipped.zip"
    #     Size = 121505
    # }
    ,@{
        Id   = "4621ad38-5b04-45ab-99fd-28661543d935"
        Name = "small file.zip"
        Size = 167
    }
)

Write-Host "List of files retrieved."

#endregion

#region Download_files

Write-Host "Calling the 'download' endpoint..."

# $downloadHeaders = @{
#     "x-raet-tenant-id" = $tenantId;
#     "Authorization"    = "Bearer $($token)";
#     "Accept"           = "application/octet-stream";
# }
# $downloadBody = @{
#     "role" = $role;
# }

foreach ($fileToDownload in $filesToDownload) {
    Write-Host "Downloading file <$($fileToDownload.Id)> with name <$($fileToDownload.Name)>."

    if (($ensureUniqueNames -eq $true) -and (Test-Path "$($downloadPath)\$($fileToDownload.Name)" -PathType Leaf)) {
        Write-Host "There is already a file with the same name in the download path. Renaming the file to be downloaded..."
        $fileToDownload.Name = ConvertTo-UniqueName_FileAPIHelper $fileToDownload.Name
        Write-Host "File will be downloaded with name <$($fileToDownload.Name)>."
    }

    [DownloadChunkManager] $downloadChunkManager = [DownloadChunkManager]::new(
        $fileApiBaseUrl,
        $fileToDownload.Id,
        $fileToDownload.Size,
        $maxChunkSize,
        "$($downloadPath)\$($fileToDownload.Name)",
        $role,
        $tenantId,
        $token
    )

    $downloadChunkManager.Download()

    # Invoke-RestMethod `
    #     -Method "Get" `
    #     -Uri "$($fileApiBaseUrl)/files/$($fileToDownload.Id)" `
    #     -Headers $downloadHeaders `
    #     -Body $downloadBody `
    #     -OutFile "$($downloadPath)\$($fileToDownload.Name)"
        
    Write-Host "File <$($fileToDownload.Id)> with name <$($fileToDownload.Name)> was downloaded."
}

Write-Host "All files were downloaded. You can find them in $($downloadPath)"

#endregion

#endregion

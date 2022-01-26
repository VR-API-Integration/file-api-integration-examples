## Imports 
& './Import.ps1'

## Import get service module
Import-Module ".\GetService.psm1" -Force

## Custom parameters
$tenantId = "MyTenantId" # Only necessary for multi-tenant token.
$longFileId = "FileId1" # Id of a big file that is going to be downloaded.
$fileId = "FileId2" # Id of another file that is going to be downloaded.
$longFilePath = "DownloadPathWithFileName1" # Path where the big file is going to be downloaded (the path must include the file name).
$filePath = "DownloadPathWithFileName2" # Path where the other file is going to be downloaded (the path must include the file name).

$mftServiceBaseAddress = "https://api.raet.com/mft/v1.0/" # Change it if you want to use another environment.
$token = "token" # Authentication token. You can use RetrieveToken.ps1 to get one.
$clientTimeout = 600 # Seconds before giving timeout error 

## Instance the fileSystemService with a longer timeout will allow to wait more for bigger files
$fileSystemService = GetFileApiFileSystemService $mftServiceBaseAddress $token $clientTimeout

## Download big file with the configured $clientTimeout
Write-Host "Download file..." -ForegroundColor Green
Write-Host "File id: " -ForegroundColor Yellow -NoNewline 
Write-Host $longFileId -ForegroundColor White
Write-Host "File path: " -ForegroundColor Yellow -NoNewline 
Write-Host $longFilePath -ForegroundColor White
Write-Host "Tenant id (optional): " -ForegroundColor Yellow -NoNewline 
Write-Host $tenantId -ForegroundColor White
$tokenSource = new-object System.Threading.CancellationTokenSource
$tokenSource.CancelAfter(30000)  ## Expressed in milliseconds
$result = $fileSystemService.DownloadFileAsync($longFileId, $longFilePath, $tenantId, $tokenSource.Token).GetAwaiter().GetResult()

## Download normal file with a shorter timeout
Write-Host "Download file..." -ForegroundColor Green
Write-Host "File id: " -ForegroundColor Yellow -NoNewline 
Write-Host $fileId -ForegroundColor White
Write-Host "File path: " -ForegroundColor Yellow -NoNewline 
Write-Host $filePath -ForegroundColor White
Write-Host "Tenant id (optional): " -ForegroundColor Yellow -NoNewline 
Write-Host $tenantId -ForegroundColor White
## The cancelation token source is used to specify a shorter timeout
$tokenSource = new-object System.Threading.CancellationTokenSource
$tokenSource.CancelAfter(30000)  ## Expressed in milliseconds
$result = $fileSystemService.DownloadFileAsync($fileId, $filePath, $tenantId, $tokenSource.Token).GetAwaiter().GetResult()

## Imports 
& './Import.ps1'

## Import get service module
Import-Module ".\GetService.psm1" -Force

## Custom parameters
$tenantId = "MyTenantId" # Only necessary for multi-tenant token.
$fileId = "FileId" # Id of the file that is going to be downloaded.
$filePath = "DownloadPathWithFileName" # Path where the file is going to be downloaded the file (the path must include the file name).

$mftServiceBaseAddress = "https://api.raet.com/mft/v1.0/" # Change it if you want to use another environment.
$token = "MyToken" # Authentication token. You can use RetrieveToken.ps1 to get one.

## Download file
Write-Host "Download file..." -ForegroundColor Green
Write-Host "File id: " -ForegroundColor Yellow -NoNewline 
Write-Host $fileId -ForegroundColor White
Write-Host "File path: " -ForegroundColor Yellow -NoNewline 
Write-Host $filePath -ForegroundColor White
Write-Host "Tenant id (optional): " -ForegroundColor Yellow -NoNewline 
Write-Host $tenantId -ForegroundColor White
$fileSystemService = GetFileApiFileSystemService $mftServiceBaseAddress $token
$cancellationToken = new-object System.Threading.CancellationToken
$result = $fileSystemService.DownloadFileAsync($fileId,$filePath,$tenantId,$cancellationToken).GetAwaiter().GetResult()

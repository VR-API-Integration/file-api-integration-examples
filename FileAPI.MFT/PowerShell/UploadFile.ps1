## Imports 
& './Import.ps1'

## Import get service module
Import-Module ".\GetService.psm1" -Force

## Custom parameters
$tenantId = "MyTenantId" # Only necessary for multi-tenant token.
$businessTypeId = 0 # Use the desired businessType.
$filePath = "UploadPathWithFileName" # Path where is the file that is going to be uploaded (the path must include the file name).

$mftServiceBaseAddress = "https://api.raet.com/mft/v1.0/" # Change it if you want to use another environment.
$token = "MyToken" # Authentication token. You can use RetrieveToken.ps1 to get one.

## Upload file
Write-Host "Uploading file..." -ForegroundColor Green
Write-Host "Bussiness type id: " -ForegroundColor Yellow -NoNewline 
Write-Host $businessTypeId -ForegroundColor White
Write-Host "File name with path: " -ForegroundColor Yellow -NoNewline 
Write-Host $filePath -ForegroundColor White
Write-Host "Tenant id (optional): " -ForegroundColor Yellow -NoNewline 
Write-Host $tenantId -ForegroundColor White
$fileSystemService = GetFileApiFileSystemService $mftServiceBaseAddress $token
$cancellationToken = new-object System.Threading.CancellationToken
$result = $fileSystemService.UploadFileAsync($businessTypeId,$filePath,$tenantId,$cancellationToken).GetAwaiter().GetResult()

## Show the result
$file = [ordered]@{
	"Id"=$result.Id; 
	"Name"=$result.Name; 
	"Size"=$result.Size;
	"CreationDate"=$result.CreationDate.ToString();
	"BusinessType"=[ordered]@{
		"Id"=$result.BusinessType.Id; 
		"Name"=$result.BusinessType.Name};
	"NumChunks"=$result.NumChunks;}
$file |  ConvertTo-Json -Depth 10 

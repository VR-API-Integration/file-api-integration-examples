function GetFileApiFileSystemService{
 
    Param(
		[parameter(Mandatory=$true)]
		$mftServiceBaseAddress,
		
		[parameter(Mandatory=$true)]
		$token,

		[parameter(Mandatory=$false)]
		$clientTimeout
    )
 
    ## Configuration
	Write-Host "Creating configuration..." -ForegroundColor Green
	$options = new-object Ftaas.Sdk.Factory.ServiceWrapperOptions
	$options.MftServiceBaseAddress = $mftServiceBaseAddress
	if ($clientTimeout) { 
		$options.ClientTimeout = $clientTimeout
	}

	Write-Host "MFT service base address: " -ForegroundColor Yellow -NoNewline 
	Write-Host $options.MftServiceBaseAddress -ForegroundColor White
	Write-Host ""

	## Get service
	Write-Host "Creating service..." -ForegroundColor Green
	$serviceFactory = new-object Ftaas.Sdk.Factory.ServiceFactory
	$fileSystemService = $serviceFactory.GetServiceInstance($options)
	Write-Host ""

	## Authorize service
	Write-Host "Authorizing service..." -ForegroundColor Green
	$fileSystemService.Authorize($token)
	Write-Host "Authentication token: " -ForegroundColor Yellow -NoNewline 
	Write-Host $token -ForegroundColor White
	Write-Host ""

	return $fileSystemService 
}
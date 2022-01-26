# File API Powershell Examples

PowerShell folder includes a collection of examples that show how to integrate the File API SDK with Powershell.

## Getting Started

Download PowerShell folder. Required data is commented in the example powershell scripts. Fill required data and run the example scripts as described in Running Examples section.

### Prerequisites

Minimim requirement is PowerShell V3. For PowerShell V3 before running the scripts TLS setting must be set by using the following PowerShell script:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
```

## Running Examples

Powershell scripts provide examples for listing, downloading and uploading files from File Api. Each operation starts with importing the required libraries and getting a file system service instance. Each powershell script is explained in below sub sections.

### Importing libraries

The powershell script **Import.ps1** imports the required libraries.

### Get service module

The powershell module **GetService.psm1** creates and returns a file system service instance. 

### Retrieving token

The powershell script **RetrieveToken.ps1** retrieves an authorization jwt token from Identity Api. Following parameters need to be provided:

- **$clientId**: User identifier.
- **$clientSecret**: User password.
- **$identityAddress**: Identity Api end point (Production end point: https://api.raet.com/authentication/token)

### Listing files

The powershell script **ListFiles.ps1** lists the available files. Following parameters need to be provided:

- **$tenantId**: Tenant id the files belong to (optional)
- **$mftServiceBaseAddress**: File Api end point (Production end point: https://api.raet.com/mft/v1.0/)
- **$token**: Authorization jwt token (obtained by using the client id and client secret from Identity Api).

### Downloading a file

The powershell script **DownloadFile.ps1** downloads the file specified by file id. Following parameters need to be provided:

- **$tenantId**: Tenant id the files belong to (optional)
- **$fileId**: Identifier of the file that is going to be downloaded.
- **$filePath**: Full file name describing where the file will be downloaded (ex: c:\files\myFile.txt)
- **$mftServiceBaseAddress**: File Api end point (Production end point: https://api.raet.com/mft/v1.0/)
- **$token**: Authorization jwt token (obtained by using the client id and client secret from Identity Api).

### Uploading a file

The powershell script **UploadFile.ps1** uploads a file to File Api. Following parameters need to be provided:

- **$tenantId**: Tenant id the files belong (is optional).
- **$businessTypeId**: Associated business type id of the file.
- **$filePath**: Full file name describing where the file will be downloaded (ex: c:\files\myFile.txt).
- **$mftServiceBaseAddress**: File Api end point (Production end point: https://api.raet.com/mft/v1.0/)
- **$token**: Authorization jwt token (obtained by using the client id and client secret from Identity Api).

## Authors

**Visma - Transporters Team**


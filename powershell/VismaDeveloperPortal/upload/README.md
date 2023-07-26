# File API PowerShell upload examples

A collection of examples to upload files with the File API using **PowerShell**.

## Prerequisites

- To run the script you need administrator privileges.
- The script was prepared for PowerShell version 5.1 or above. With lower versions it might not work properly.
- Files to be uploaded cannot be bigger than 10 GB.
- Chunksize is limited to 100 MB (4 MB is suggested as most efficient)

## Getting Started

Download the **file-api-integration-examples** repository.

Inside the **powershell\VismaDeveloperPortal\upload** folder you can find these files:

- **UploadFile.ps1**: Script example to upload specified files.
- **config.xml**: Configuration of the **UploadFile.ps1** script.

## Running Examples

### Upload files

The script will upload all the files matching the configuration.

1. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding the configuration** section to understand the meaning of each parameter.
2. Run the **UploadFile.ps1** script with the desired parameters.

The first time you execute the script, it will ask for your credentials and will save them securely in your computer in the path specified in the configuration.  
The next executions will use the saved credentials unless you manually specify the opposite (see **Parameters** section).

#### Parameters

**`-ConfigPath`**
> Configuration full path.
>
> **Mandatory:** False  
> **Default value:** {UploadFile.ps1 folder}\config.xml
>
> **Example:** -ConfigPath "C:\Users\Foorby\config.xml"

**`-RenewCredentials`**
> Indicates if you want to renew the credentials saved in the system (true) or keep using the saved one (false).  
> This parameter is useful in case you changed your client ID or client secret.  
> In most of the cases you won't need this parameter set.
>
> **Mandatory:** False  
> **Default value:** $false
>
> **Example:** -RenewCredentials $true

#### Example 1. Upload files using the default configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\upload\UploadFile.ps1"
```

#### Example 2. Upload files specifying the configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\upload\UploadFile.ps1" -ConfigPath "C:\Users\Foorby\config.xml"
```

#### Example 3. Upload files using new credentials

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\upload\UploadFile.ps1" -RenewCredentials $true
```

## Understanding the configuration

Inside the **config.xml** file you will find these parameters:

### Attributes of the `Credentials` element

**`Path`**
> XML file path where the credentials will be stored.  
> :warning: It's important that the file you put in the path has an .xml extension, otherwise the example will not work properly.
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\upload\credentials\credentials_integration.xml

### Attributes of the `Services` element

**`FileApiBaseUrl`**
> File API base URL.
>
> It should be set to **<https://fileapi.youforce.com/v1.0>**

<br />


**`AuthenticationTokenApiBaseUrl`**
> Authentication token API base URL.
>
> It should be set to **<https://connect.visma.com/connect>**

### Attributes of the `Authentication` element

**`VismaConnectTenantId`**
> The Visma developer portal tenant ID.

<br />

### Attributes of the `Logs` element

**`Enabled`**
> Indicates if you want to store the logs in your machine.
> 
> Must be set to any of these values:  
> **· false:** the logs will only be shown in the console.  
> **· true:** the logs will be shown in the console and will be stored in your machine.

<br/>

**`Path`**
> Path where the logs will be stored.  
> If the attribute **`Logs`**>**`Enabled`** is set to **`false`**, this attribute will do nothing.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\upload\logs

### Attributes of the `Upload` element

**`BusinessTypeId`**
> The business type id of the file to upload.
>
> **Example:** 9890988

<br/>

**`Path`**
> Full path of the directory that contains the files to upload
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\upload\files

<br/>

**`Filter`**
> The filemask that will select the files to upload
>
> **Example:** data*.xml

<br/>

**`ArchivePath`**
> Full path of the directory where sussessfully uploaded files will be archived to.
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\upload\archive

<br/>

**`ChunkSize`**
> Size of chunks (MB) used to send large files (default: 4 MB is most efficient).
>
> **Example:** 4

<br/>

## Example of a valid configuration

```xml
<Configuration>
    <Credentials>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\upload\credentials\credentials_integration.xml</Path>
    </Credentials>

    <Services>
        <FileApiBaseUrl>https://fileapi.youforce.com/v1.0</FileApiBaseUrl>
        <AuthenticationTokenApiBaseUrl>https://connect.visma.com/connect</AuthenticationTokenApiBaseUrl>
    </Services>

    <Authentication>
        <VismaConnectTenantId>11111111-1111-1111-1111-111111111111</VismaConnectTenantId>
    </Authentication>

    <Logs>
        <Enabled>true</Enabled>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\upload\logs</Path>
    </Logs>

    <Upload>
        <BusinessTypeId>9890988</BusinessTypeId>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\upload\files</Path>
        <Filter>data*.xml</Filter>
        <ArchivePath>C:\Visma\File API\Ftaas.Examples\powershell\upload\archive</ArchivePath>
        <Chunksize>4</ChunkSize>
    </Upload>
</Configuration>
```

## Authors

**Visma - Transporters Team**

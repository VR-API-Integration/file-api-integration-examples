# File API PowerShell upload examples

A collection of examples to upload files with the File API using **PowerShell**.

## Prerequisites

- The script was prepared for PowerShell version 5.1 or above. With lower versions it might not work properly.
- Files to be uploaded cannot be bigger than 100 MB.

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
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload\UploadFile.ps1"
```

#### Example 2. Upload files specifying the configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload\UploadFile.ps1" -ConfigPath "C:\Users\Foorby\config.xml"
```

#### Example 3. Upload files using new credentials

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload\UploadFile.ps1" -RenewCredentials $true
```

## Understanding the configuration

Inside the **config.xml** file you will find these parameters:

### Attributes of the `Credentials` element

**`Path`**
> XML file path where the credentials will be stored.  
> :warning: It's important that the file you put in the path has an .xml extension, otherwise the example will not work properly.
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\credentials\credentials_integration.xml

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
> The Visma developer portal tenant id.

<br />

### Attributes of the `Upload` element

**`BusinessTypeId`**
> The business type id of the file to upload.
>
> **Example:** 9890988

<br/>

**`Path`**
> Full path of the directory that contains the files to upload
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload

<br/>

**`Filter`**
> The filemask that will select the files to upload
>
> **Example:** data*.xml

<br/>

**`ArchivePath`**
> Full path of the directory where sussessfully uploaded files will be archived to.
>
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\archive

<br/>

## Example of a valid configuration

```xml
<Configuration>
    <Credentials>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\credentials\credentials_integration1.xml</Path>
    </Credentials>

    <Services>
        <FileApiBaseUrl>https://fileapi.youforce.com/v1.0</FileApiBaseUrl>
        <AuthenticationTokenApiBaseUrl>https://connect.visma.com/connect</AuthenticationTokenApiBaseUrl>
    </Services>

    <Authentication>
        <VismaConnectTenantId>11111111-1111-1111-1111-111111111111</VismaConnectTenantId>
    </Authentication>

    <Upload>
        <BusinessTypeId>9890988</BusinessTypeId>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\upload</Path>
        <Filter>data*.xml</Filter>
        <ArchivePath>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\archive</ArchivePath>
    </Upload>
</Configuration>
```

## Authors

**Visma - Transporters Team**
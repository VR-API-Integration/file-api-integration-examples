# File API PowerShell download examples

A collection of examples to download files with the File API using **PowerShell**.

## Prerequisites

- The script was prepared for PowerShell version 5.1 or above. With lower versions it might not work properly.
- Files to be downloaded cannot be bigger than 2 GB.

## Getting Started 

Download the **file-api-integration-examples** repository.

Inside the **powershell\download** folder you can find these files:
- **DownloadFiles.ps1**: Script example to download specified files.
- **config.xml**: Configuration of the **DownloadFiles.ps1** script.

## Running Examples

### Download files

The script will download all the files matching the configuration.

1. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding the configuration** section to understand the meaning of each parameter.
2. Run the **DownloadFiles.ps1** script with the desired parameters.

<!-- ---
**NOTE**

The first time you execute the script, it will ask for your credentials and will save them securely in your computer, in the path specified in the configuration.  
The next executions will use the saved credentials unless you manually specify the opposite (see **Parameters** section).

--- -->

> **_NOTE:_** The first time you execute the script, it will ask for your credentials and will save them securely in your computer, in the path specified in the configuration.  
> The next executions will use the saved credentials unless you manually specify the opposite (see **Parameters** section).
#### Parameters

**`-ConfigPath`**
> Configuration full path.
> 
> **Mandatory:** False  
> **Default value:** {DownloadFiles.ps1 folder}\config.xml 
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

#### Example 1. Download files using the default configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\download\DownloadFiles.ps1"
```

#### Example 2. Download files specifying the configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\download\DownloadFiles.ps1" -ConfigPath "C:\Users\Foorby\config.xml"
```

#### Example 3. Download files using new credentials

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\download\DownloadFiles.ps1" -RenewCredentials $true
```

## Understanding the configuration

Inside the **config.xml** file you will find these parameters:

### Attributes of the `Credentials` element

**`StorageFilePath`**
> XML file path where the credentials will be storaged.  
> :warning: It's important that the file you put in the path has an .xml extension, otherwise the example will not work properly.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\credentials\credentials_integration1.xml

### Attributes of the `Services` element

**`FileApiBaseUrl`**
> File API base URL.
> 
> In the vast majority of scenarios, it should be set to **https://api.raet.com/mft/v1.0**

<br/>

**`AuthenticationTokenApiBaseUrl`**
> Authorization token API base URL.
> 
> In the vast majority of scenarios, it should be set to **https://api.raet.com/authentication**

### Attributes of the `Download` element

**`TenantId`**
> Tenant you will use to download the files.
> 
> **Example:** 1122334

<br/>

**`Role`**
> Role of your application.
> 
> Must be set to any of these values:  
> **· Subscriber:** to download files provided to you (the most common scenario).  
> **· Publisher:** to download files provided by you.

<br/>

**`Path`**
> Path where the files will be downloaded.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\download\output

<br/>

**`EnsureUniqueNames`**
> Indicates if you want to rename the files to be unique before downloading them.
> 
> Must be set to any of these values:  
> **· false:** the downloaded file will replace any existing file with the same name.  
> **· true:** the downloaded file will be renamed if there is any existing file with the same name.  
> &nbsp;&nbsp;Format: {original file name}_{timestamp}.{original extension}  
> &nbsp;&nbsp;Original: TestFile.txt  
> &nbsp;&nbsp;Renamed: TestFile_20220304T1229027372Z.txt

<br/>

**`Filter`**
> If empty, all the available (not downloaded yet) files will be listed.  
> You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides__search__for__files.html).
>
> **Example:** startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z

## Example of a valid configuration

```xml
<Configuration>
    <Credentials>
        <StorageFilePath>C:\Visma\File API\Ftaas.Examples\powershell\credentials\credentials_integration1.xml</StorageFilePath>
    </Credentials>

    <Services>
        <FileApiBaseUrl>https://api.raet.com/mft/v1.0</FileApiBaseUrl>
        <AuthenticationTokenApiBaseUrl>https://api.raet.com/authentication</AuthenticationTokenApiBaseUrl>
    </Services>

    <Download>
        <TenantId>1122334</TenantId>
        <Role>subscriber</Role>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\download\output</Path>
        <EnsureUniqueNames>true</EnsureUniqueNames>
        <Filter>startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z</Filter>
    </Download>
</Configuration>
```

## Authors

**Visma - Transporters Team**

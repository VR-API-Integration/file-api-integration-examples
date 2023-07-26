# File API PowerShell download examples

A collection of examples to download files with the File API using **PowerShell**.

## Prerequisites

- To run the script you need administrator privileges.
- The script was prepared for PowerShell version 5.1 or above. With lower versions it might not work properly.
- Files to be downloaded cannot be bigger than 2 GB.

## Getting Started 

Download the **file-api-integration-examples** repository.

Inside the **powershell\VismaDeveloperPortal\download** folder you can find these files:
- **DownloadFiles.ps1**: Script example to download specified files.
- **config.xml**: Configuration of the **DownloadFiles.ps1** script.

## Running Examples

### Download files

The script will download all the files matching the configuration.

1. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding the configuration** section to understand the meaning of each parameter.
2. Run the **DownloadFiles.ps1** script with the desired parameters.

The first time you execute the script, it will ask for your credentials and will save them securely in your computer in the path specified in the configuration.  
The next executions will use the saved credentials unless you manually specify the opposite (see **Parameters** section).

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
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\DownloadFiles.ps1"
```

#### Example 2. Download files specifying the configuration path

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\DownloadFiles.ps1" -ConfigPath "C:\Users\Foorby\config.xml"
```

#### Example 3. Download files using new credentials

```powershell
& "C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\DownloadFiles.ps1" -RenewCredentials $true
```

## Understanding the configuration

Inside the **config.xml** file you will find these parameters:

### Attributes of the `Credentials` element

**`Path`**
> XML file path where the credentials will be storaged.  
> :warning: It's important that the file you put in the path has an .xml extension, otherwise the example will not work properly.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\credentials\credentials_integration1.xml

### Attributes of the `Services` element

**`FileApiBaseUrl`**
> File API base URL.
> 
> It should be set to **https://fileapi.youforce.com/v1.0**

<br/>

**`AuthenticationTokenApiBaseUrl`**
> Authentication token API base URL.
> 
> It should be set to **https://connect.visma.com/connect**

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
> If the attribute **`Logs`**>**`Enabled`** is set to false, this attribute do nothing.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\logs

### Attributes of the `Download` element

**`Role`**
> Role of your application.
> 
> Must be set to any of these values:  
> **· Subscriber:** to download files provided to you (the most common scenario).  
> **· Publisher:** to download files uploaded by you.

<br/>

**`Path`**
> Path where the files will be downloaded.
> 
> **Example:** C:\Visma\File API\Ftaas.Examples\VismaDeveloperPortal\powershell\download\output

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
> You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides_search_for_files.html).
>
> **Example:** startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z

## Example of a valid configuration

```xml
<Configuration>
    <Credentials>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\credentials\credentials_integration.xml</Path>
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
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\logs</Path>
    </Logs>

    <Download>
        <Role>subscriber</Role>
        <Path>C:\Visma\File API\Ftaas.Examples\powershell\VismaDeveloperPortal\download\output</Path>
        <EnsureUniqueNames>true</EnsureUniqueNames>
        <Filter>startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z</Filter>
    </Download>
</Configuration>
```
## Authors

**Visma - Transporters Team**

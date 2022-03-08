# File API Powershell examples

A collection of examples to integrate with the File API using **Powershell**.

## Prerequisites

- Powershell version 5.1 or above.
- Files to be downloaded cannot be bigger than 2 GB.

## Getting Started 

Download the **file-api-integration-examples** repository.

Inside the **powershell** folder you can find these files:
- **DownloadFiles.ps1**: Script example to download specified files.
- **config.xml**: Configuration of the **DownloadFiles.ps1** script.

## Running Examples

### Download files

The script will download all the files matching the configuration.

1. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding the configuration** section to understand the meaning of each parameter.
2. Run the **DownloadFiles.ps1** script with the desired parameters.  

#### Parameters

`-ConfigPath`
> Path of the configuration.
>
> Mandatory: False
> Default value: {DownloadFiles.ps1 folder}\config.xml 
>
> Example: -ConfigPath "C:\Visma\File API\Download"

## Understanding the configuration

Inside the **config.xml** file you will see these parameters:

### Attributes of the `Credentials` element

`ClientId`
> Client identifier of your application.  
> Also known as Consumer Key.
> 
> **Example:** K82ixRsw0oiwWerjm123FKdhjfpqel2q

<br/>

`ClientSecret`
> Client secret of your application.  
> Also known as Secret Key.
> 
> **Example:** diUer712Lkfd9fDh

### Attributes of the `Download` element

`TenantId`
> Tenant you will use to download the files.
> 
> **Example:** 1122334

<br/>

`Role`
> Role of your application.
> 
> Must be set to any of these values:  
> **· Subscriber:** to download files provided to you (the most common scenario).  
> **· Publisher:** to download files provided by you.

<br/>

`Path`
> Path where the files will be downloaded.
> 
> **Example:** C:\Visma\Integrations\Download

<br/>

`EnsureUniqueNames`
> Indicates if you want to rename the files to be unique before downloading them.
> 
> Must be set to any of these values:  
> **· false:** the downloaded file will replace any existing file with the same name.  
> **· true:** the downloaded file will be renamed if there is any existing file with the same name.  
> &nbsp;&nbsp;Format: {original file name}_{timestamp}.{original extension}  
> &nbsp;&nbsp;Original: TestFile.txt  
> &nbsp;&nbsp;Renamed: TestFile_20220304T1229027372Z.txt

<br/>

`Filter`
> If empty, all the available (not downloaded yet) files will be listed.  
> You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides__search__for__files.html).
>
> **Example:** startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z

## Example of a valid configuration

```xml
<Configuration>
    <Credentials>
        <ClientId>K82ixRsw0oiwWerjm123FKdhjfpqel2q</ClientId>
        <ClientSecret>diUer712Lkfd9fDh</ClientSecret>
    </Credentials>

    <Download>
        <TenantId>1122334</TenantId>
        <Role>subscriber</Role>
        <Path>C:\Visma\Integrations\Download</Path>
        <EnsureUniqueNames>true</EnsureUniqueNames>
        <Filter>startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z</Filter>
    </Download>
</Configuration>
```

## Authors

**Visma - Transporters Team**

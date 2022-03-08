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
```
Type:           String
Mandatory:      False
Default value:  {DownloadFiles.ps1 folder}\config.xml
Description:    Path of the configuration.
Example:        -ConfigPath "C:\Visma\File API\Download"
```

## Understanding the configuration

Inside the **config.xml** file you will see theses parameters:
- **\<Credentials>\<ClientId>**: Client identifier of your application.  
Also known as **Consumer Key**.
- **\<Credentials>\<ClientSecret>**: Client secret of your application.  
Also known as **Secret Key**.
- **\<Download>\<TenantId>**: Tenant of your application.
- **\<Download>\<Role>**: Role of your application.  
__subscriber__ if you consume files (the most common scenario).  
__publisher__ if you provide files.
- **\<Download>\<Path>**: Path where the files will be downloaded.
- **\<Download>\<EnsureUniqueNames>**: Indicates if you want to rename the files to be unique before downloading them.  
__false__ means that if there is already a file with the same name in the download path, the file will be **replaced** by the new one.  
__true__ means that if there is already a file with the same name in the download path, the file to be downloaded will be **renamed** so it doesn't collide with the existing one.  
The new name will have this format: __{original file name}_{timestamp}.{original extension}__.  
E.g. original file: __TestFile.txt__ / renamed file: __TestFile_20220304T1229027372Z.txt__.
- **\<Download>\<Filter>**: Indicates the kind of files that will be retrieved from the list.  
If empty, all the available (not downloaded yet) files will be listed.  
You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides__search__for__files.html).

## Example of a valid **config.xml**

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

## Authors

**Visma - Transporters Team**

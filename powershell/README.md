# File API Powershell examples

A collection of examples to integrate with the File API using **Powershell**.

## Prerequisites

- Powershell version 5.1 or above.
- Files to be downloaded cannot be bigger than 2 GB.

## Getting Started 

Download the **file-api-integration-examples** repository. These examples use the folder **powershell**.

Inside the folder there are two files:
- **DownloadFiles.ps1**: Powershell example to download specified files.
- **config.xml**: Configuration of the **DownloadFiles.ps1** script.

## Running Examples

1. Place the files **config.xml** and **DownloadFiles.ps1** in the same folder. Do not rename **config.xml**.
2. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding configuration parameters** section to understand the meaning of each parameter.
3. Run the **DownloadFiles.ps1** script.

The script will download all the files specified in the configuration.

## Understanding configuration parameters

Inside the **config.xml** file you will see theses parameters:
- **\<Configuration>\<ClientId>**: Client identifier of your application.  
Also known as **Consumer Key**.
- **\<Configuration>\<ClientSecret>**: Client secret of your application.  
Also known as **Secret Key**.
- **\<Configuration>\<TenantId>**: Tenant of your application.
- **\<Configuration>\<Role>**: Role of your application.  
__subscriber__ if you consume files (the most common scenario).  
__publisher__ if you provide files.
- **\<Download>\<Path>**: Path where the files will be downloaded.
- **\<Download>\<EnsureUniqueNames>**: Indicates if you want to rename the files to be unique before downloading them.  
__false__ means that if there is already a file with the same name in the download path, the file will be **replaced** by the new one.  
__true__ means that if there is already a file with the same name in the download path, the file to be downloaded will be **renamed** so it doesn't collide with the existing one.  
The new name will have this format: __original file name - \<timestamp>.original extension__.  
E.g. original file: __TestFile.txt__ / renamed file: __TestFile - 20220304T1229027372Z.txt__.
- **\<List>\<Filter>**: Indicates what kind of files will be retrieved from the list. These files will also be downloaded  
If empty, all the available (not downloaded yet) files will be listed.  
You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides__search__for__files.html).


## Example of a valid **config.xml**

    <Configuration>
        <Credentials>
            <ClientId>K82ixRsw0oiwWerjm123FKdhjfpqel2q</ClientId>
            <ClientSecret>diUer712Lkfd9fDh</ClientSecret>
            <TenantId>1122334</TenantId>
            <Role>subscriber</Role>
        </Credentials>
    
        <Download>
            <Path>C:\Visma\Integrations\Download</Path>
            <EnsureUniqueNames>true</EnsureUniqueNames>
            <Filter>startsWith(FileName, 'employee_profile') and uploadDate gt 2022-02-08T11:02:00Z</Filter>
        </Download>
    </Configuration>

## Authors

**Visma - Transporters Team**
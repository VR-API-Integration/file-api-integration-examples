# File API Powershell (no dependencies) Examples

**powershell-with-no-dependencies** folder includes a collection of examples that show how to integrate the **File API** with **native Powershell**.

## Prerequisites

- Powershell version 5.1 or above.
- Files to be downloaded cannot be bigger than 2 GB.

## Getting Started 

Download **powershell-with-no-dependencies** folder.

Inside the folder there is a batch file called **DownloadFiles.bat** which can be used to download a file from File API.

Inside the folder there are two files:
- DownloadFiles.ps1: Powershell example to download specified files.
- config.xml: Configuration of the DownloadFiles.ps1 script.

## Running Examples

1. Place the files **config.xml** and **DownloadFiles.ps1** in the same folder. Do not rename **config.xml**.
2. Open **config.xml** with any text editor (e.g. Notepad) and fill the parameters.  
See **Understanding configuration parameters** section to see the meaning of each parameter.
3. Double click the file **DownloadFiles.ps1** to run the script

The script will download all the files specified in the configuration.

## Understanding configuration parameters

Inside the **config.xml** file you will see theses parameters:
- **\<Configuration>\<ClientId>**: Client identifier of your application.  
Also known as **Consumer Key**.
- **\<Configuration>\<ClientSecret>**: Client secret of your application.  
Also known as **Secret Key**.
- **\<Configuration>\<TenantId>**: Tenant of your application.
- **\<Configuration>\<Role>**: Role of your application.  
_subscriber_ if you to consume files (the most common scenario).  
_publisher_ if you provide files.
- **\<Download>\<Path>**: Path where the files will be downloaded.
- **\<Download>\<EnsureUniqueNames>**: Indicates if you want to rename the files to be unique before downloading them.  
_true_ means that if there is already a file with the same name in the download path, the file to be downloaded will be **renamed** so it doesn't collide with the existing one.  
_false_ means that if there is already a file with the same name in the download path, the file will be **replaced** by the new one. The new name will have this format: _original file name - \<timestamp>.original extension_ (e.g. original file: _TestFile.txt_ / renamed file: _TestFile - 20220304T1229027372Z.txt_ )
- **\<Download>\<Filter>**: Indicates what kind of files should be downloaded.  
If empty, all the available (not downloaded yet) files will be downloaded.  
You can learn more about filters in the [File API documentation](https://vr-api-integration.github.io/file-api-documentation/guides_search_for_files.html).


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

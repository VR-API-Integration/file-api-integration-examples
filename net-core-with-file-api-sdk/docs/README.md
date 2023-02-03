MftWebApi SDKs
=========

[![Build Status](https://dev.azure.com/raet/RaetOnline/_apis/build/status/Team%20Transporters/FTaaS/Ftaas.Sdk?branchName=master)](https://dev.azure.com/raet/RaetOnline/_build/latest?definitionId=4631&branchName=master)

Library that allows to send and receive files to the File API.
It comes in two different flavors: [Ftaas.Sdk.FileSystem](#ftaassdkfilesystem) and [Ftaas.Sdk.Streaming](#ftaassdkstreaming). The first one allows 
to send and receive files directly on your file system, while the second is more configurable, as the source of files are streams.

# FTaaS.Sdk.FileSystem #

Integrate with File API with file system sources, sending and downloading files from and into directories.

## Getting started ##

1. Install the file system Nuget package into your ASP.NET Core application.

    ```
    Package Manager : Install-Package VismaRaet.FileApi.Sdk.FileSystem -Version 1.10.0
    CLI : dotnet add package VismaRaet.FileApi.Sdk.FileSystem --version 1.10.0
    ```

2. In the `ConfigureServices` method of `Startup.cs`, register the FileSystem integrator.

    ```csharp
    using Ftaas.Sdk.FileSystem;
    ```

    ```csharp
    services.AddFileSystemService(
                            options =>
                            {
                                options.MftServiceBaseAddress = mftService;
                                options.ChunkMaxBytesSize = Configuration.GetValue<int>("chunk_max_bytes_size");
                                options.ClientTimeout = Configuration.GetValue<int>("client_timeout");
                                options.ConcurrentConnectionsCount = Configuration.GetValue<byte>("concurrent_connections");
                            },
                            async (serviceProvider) =>
                            {
                                await serviceProvider.GetRequiredService<ISecureStore>().TryRetrieveAsync<string>($"ftaascli:{mftService}", out var serializedLoginSession);
                                var loginSession = JsonConvert.DeserializeObject<LoginSession>(serializedLoginSession);
                                var bearerToken = loginSession.AuthorizationToken;
                                bearerToken.ValidateJwtToken();
                                return bearerToken;
                            });
    ```

    `IServiceCollection AddFileSystemService(
            this IServiceCollection services,
            Action<ServiceConfigurationOptions> optionsConfiguration,
            Func<IServiceProvider, Task<string>> bearerTokenFactory)` 

    `optionConfiguration`: 
    - MftServiceBaseAddress: File API endpoint: 
	    - Production: https://api.raet.com/mft/v1.0/
	- ChunkMaxBytesSize: optional, maximum number of bytes that will be uploaded on a call to File API.
   The default value is the maximum size accepted on File API: 4194304, 4 MB. This is the recommended configuration, only to be decreased if you have connection issues.
   The file will be splitted on chunks of this size and uploaded on different calls.
	- ConcurrentConnectionsCount: optional, number of parallel requests to File API. 
   The default value is the maximum, 6. The minimum is 1. It's recommended to set this value according to your CPU capabilities.
   When uploading a big file (size > ChunkMaxBytesSize) it will upload up to  ConcurrentConnectionsCount chunks of the file simultaniously, when performing a multitenant list, files of different tenants will be retrieved in parallel.
   ---
    `bearerTokenFactory`: Function that retrieves an authorization token.

## Usage ##

### Upload ###

`UploadFileAsync` uploads a file and returns the metadata of the file created on MFT: The Id can be used to download the file by the subscribers.

_NOTE: If the file size is greater than the maximum chunk size configured, it will be uploaded by chunks._

#### Task<FileUploadInfo> UploadFileAsync(long businessTypeId, string filePath, string tenantId, CancellationToken cancellationToken) ####
`businessTypeId`: bussinessTypeId the file will be uploaded to.\
`filePath`: absolute path of the file to upload.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the upload task will observe.

### Delete ###

`DeleteFileAsync` sets a subscriber file to 'deleted'.

#### Task DeleteFileAsync(string fileId, string tenantId, CancellationToken cancellationToken) ####
`fileId`: GUID of the file to delete.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the delete task will observe.

### Download ###

`DownloadFileAsync` downloads the requested file to the specified path.

_NOTE: If the file already exists, it will be replaced with the downloaded one._

#### Task DownloadFileAsync(string fileId, string filePath, string tenantId, CancellationToken cancellationToken) ####
`fileId`: GUID of the file to download.\
`filePath`: absolute path where the file will be created.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the download task will observe.

### List ###

`GetAvailableFilesAsync` retrieves a list of metadatas of the available files.

#### Task<PaginatedItems<FileInfo>> GetAvailableFilesAsync(Pagination pagination, string tenantId, string filter, string orderBy, CancellationToken cancellationToken) ####
`pagination`: (optional) if specified, the list will have the specified items size and will be the index page. If not, the first twenty files metadata will be retrieved.\
`tenantId`: (optional) tenantId.\
`filter`: (optional) if empty, it will retrieve the not downloaded, nor deleted files for the subscriber. Here you can find some filter examples: [File API filters](https://vr-api-integration.github.io/file-api-documentation/guides_search_for_files.html).\
`orderBy`: (optional) if empty, the files will be sorted by upload date, latest first. Here you can find some sorting examples: [File API sorting](https://vr-api-integration.github.io/file-api-documentation/guides_sort_files.html).\
`cancellationToken`: (optional) the CancellationToken that the list task will observe.

### Has Subscription ###

Returns true if a business type has subscribers for the specified authorized tenant and false otherwise.

#### Task<bool> HasSubscriptionAsync(long businessTypeId, string tenantId, CancellationToken cancellationToken) ####
`businessTypeId`: business type.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the task will observe.

# FTaaS.Sdk.Streaming #

Integrate with File API with stream sources.

## Getting started ##

1. Install the streams Nuget package into your ASP.NET Core application.

    ```
    Package Manager : Install-Package VismaRaet.FileApi.Sdk.Streaming -Version 1.10.0
    CLI : dotnet add package VismaRaet.FileApi.Sdk.Streaming --version 0.10.0
    ```

2. In the `ConfigureServices` method of `Startup.cs`, register the Streaming integrator.


    ```csharp
    using Ftaas.Sdk.Streaming;
    ```

    ```csharp
    services.AddStreamingService(
                            options =>
                            {
                                options.MftServiceBaseAddress = mftService;
                                options.ChunkMaxBytesSize = Configuration.GetValue<int>("chunk_max_bytes_size");
                                options.ClientTimeout = Configuration.GetValue<int>("client_timeout");
                                options.ConcurrentConnectionsCount = Configuration.GetValue<byte>("concurrent_connections");
                            },
                            async (serviceProvider) =>
                            {
                                await serviceProvider.GetRequiredService<ISecureStore>().TryRetrieveAsync<string>($"ftaascli:{mftService}", out var serializedLoginSession);
                                var loginSession = JsonConvert.DeserializeObject<LoginSession>(serializedLoginSession);
                                var bearerToken = loginSession.AuthorizationToken;
                                bearerToken.ValidateJwtToken();
                                return bearerToken;
                            });
    ```

    `IServiceCollection AddStreamingService(
            this IServiceCollection services,
            Action<ServiceConfigurationOptions> optionsConfiguration,
            Func<IServiceProvider, Task<string>> bearerTokenFactory)` 

    `optionConfiguration`: 
    - MftServiceBaseAddress: File API endpoint: 
	    - Production: https://api.raet.com/mft/v1.0/
	- ChunkMaxBytesSize: optional, maximum number of bytes that will be uploaded on a call to File API.
   The default value is the maximum size accepted on File API: 4194304, 4 MB. This is the recommended configuration, only to be decreased if you have connection issues.
   The file will be splitted on chunks of this size and uploaded on different calls.
	- ConcurrentConnectionsCount: optional, number of parallel requests to File API. 
   The default value is the maximum, 6. The minimum is 1. It's recommended to set this value according to your CPU capabilities.
   When uploading a big file (size > ChunkMaxBytesSize) it will upload up to  ConcurrentConnectionsCount chunks of the file simultaniously, when performing a multitenant list, files of different tenants will be retrieved in parallel.
   ---
    `bearerTokenFactory`: Function that retrieves an authorization token.

## Usage ##

### Upload ###

`UploadFileAsync` uploads a file and returns the metadata of the file created on MFT: The Id can be used to download the file by the subscribers.

_NOTE: If the file size is greater than the maximum chunk size configured, it will be uploaded by chunks._

#### Task<FileUploadInfo> UploadFileAsync(FileUploadRequest request, Stream stream, string tenantId, CancellationToken cancellationToken) ####
`request`: composed by fileName and bussinessTypeId.\
`stream`: stream containing the bytes of the file.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the upload task will observe.

### Delete ###

`DeleteFileAsync` sets a subscriber file to 'deleted'.

#### Task DeleteFileAsync(string fileId, string tenantId, CancellationToken cancellationToken) ####
`fileId`: GUID of the file to delete.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the delete task will observe.

### Download ###

`DownloadFileAsync` reads the requested file content to a stream.

#### Task DownloadFileAsync(string fileId, Stream stream, string tenantId, CancellationToken cancellationToken) ####
`fileId`: GUID of the file to download.\
`stream`: stream where the bytes of the file will be written.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the download task will observe.

### List ###

`GetAvailableFilesAsync` retrieves a list of metadatas of the available files.
#### Task<PaginatedItems<FileInfo>> GetAvailableFilesAsync(Pagination pagination, string tenantId, string filter, string orderBy, CancellationToken cancellationToken) ####
`pagination`: (optional) if specified, the list will have the specified items size and will be the index page. If not, the first twenty files metadata will be retrieved.\
`tenantId`: (optional) tenantId.\
`filter`: (optional) if empty, it will retrieve the not downloaded, nor deleted files for the subscriber. Here you can find some filter examples: [File API filters](https://vr-api-integration.github.io/file-api-documentation/guides_search_for_files.html).\
`orderBy`: (optional) if empty, the files will be sorted by upload date, latest first. Here you can find some sorting examples: [File API sorting](https://vr-api-integration.github.io/file-api-documentation/guides_sort_files.html).\
`cancellationToken`: (optional) the CancellationToken that the list task will observe.

### Has Subscription ###

Returns true if a business type has subscribers for the specified authorized tenant and false otherwise.

#### Task<bool> HasSubscriptionAsync(long businessTypeId, string tenantId, CancellationToken cancellationToken) ####
`businessTypeId`: business type.\
`tenantId`: (optional) tenantId.\
`cancellationToken`: (optional) the CancellationToken that the task will observe.
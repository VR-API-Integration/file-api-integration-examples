# Changelog 
Date | Package | Version | Description 
--- | --- | --- | --- 
2024-12-04 | ALL | v2.4.0 | Add HealthCheck method
2024-12-04 | ALL | v2.3.2 | Remove MyGet packages
2024-05-07 | ALL | v2.3.0 | Update MyGet Service Connection
2024-03-07 | ALL | v2.2.0 | Support custom metadata
2024-01-08 | ALL | v2.1.0 | Remove unused dependencies
2023-02-20 | ALL | v2.0.0 | Rename Delete method. Previous DeleteAsync method has been renamed to SetFileToDeletedAsync to avoid misunderstandings, as it doesn't delete files, it marks the file as 'deleted' for a subscriber.
2023-02-03 | ALL | v1.22.0 | Add deleted and deletedDate fields to list response.
2023-02-02 | ALL | v1.21.0 | Add subscriber delete documentation to the examples.
2023-02-02 | ALL | v1.20.0 | Breaking changes: IService includes a new method. Add delete method to SDK. This allows a subscriber to mark a file as deleted, won't delete the file.
2022-09-23 | ALL | v1.19.0 | Add count to concurrentQueue
2022-03-07 | ALL | v1.18.0 | Add copyright to the packages
2022-01-18 | ALL | v1.17.0 | Internal updates
2022-01-11 | ALL | v1.16.0 | Internal updates
2022-01-11 | ALL | v1.15.0 | Internal updates to improve reliability
2021-10-11 | ALL | v1.14.0 | Internal Updates
2021-10-08 | ALL | v1.13.0 | Update vulnerable packages
2021-10-07 | ALL | v1.12.0 | Update vulnerable packages
2021-10-01 | ALL | v1.11.0 | Upgrade .NET Core version to 3.1  We were using .NET Core 2.2. That version is out of support, so we upgraded it to .NET Core 3.1
2021-08-20 | ALL | v1.10.0 | Implementation of HasSubscription method
2021-08-20 | ALL | v1.9.0 | Internal updates
2021-08-10 | ALL | v1.8.0 | Internal updates
2021-06-07 | ALL | v1.7.0 | Added documentation for HasSubscribers method
2021-06-04 | ALL | v1.6.0 | Fixed pipeline step to upload libraries to GitHub
2021-06-04 | ALL | v1.5.0 | Created nonfunctional method to check if a business type has subscription for a specific tenant
2021-05-12 | ALL | v1.4.0 | Minor pipeline improvements
2021-05-12 | ALL | v1.3.0 | Fix version issue in nuget.org
2021-05-11 | ALL | v1.2.0 | Run Polaris only on schedule
2021-03-11 | ALL | v1.1.0 | Improve pipeline to publish changelog to the example repository
2021-03-04 | ALL | v1.0.0 | Package is now deployed to Nuget
2021-02-18 | ALL | v0.24.0 | Security changes related to Dependency Confusion Vulnerability are implemented
2020-11-16 | ALL | v0.23.0 | Added pipeline retention for releases  Retain pipeline data when release reach REL stage
2020-10-10 | ALL | v0.22.0 | Update SonarQube Service Connection
2020-09-17 | ALL | v0.21.0 | Fixed nuget packages publishing issues
2020-09-09 | ALL | v0.20.0 | QA improvements
2020-08-25 | ALL | v0.19.0 | Fixed incomplete upload of big files when the connection is too slow
2020-07-29 | ALL | v0.18.0 | Added underlying http requests retrying
2020-07-21 | ALL | v0.17.0 | Remove ClientBufferSize, support for files longer than 2Gb  Remove ClientBufferSize, support for files longer than 2Gb
2020-07-21 | ALL | v0.16.0 | Solved a bug where big files (8 MB) might be uploaded corrupted.
2020-07-15 | ALL | v0.15.0 | Added HttpClient buffer size configuration options
2020-07-10 | ALL | v0.14.0 | Compatibility with .Net 4.5. Fixed some bugs. Improved responses.
2020-07-09 | ALL | v0.13.0 | Added timeout to download big files
2020-07-07 | ALL | v0.12.0 | Updates for download files to multiple folders
2020-06-16 | ALL | v0.11.0 | Adapt SDK for.Net Framework
2020-06-15 | ALL | v0.10.0 | Create documentation and deliver examples of uploads and downloads of files using .Net SDK
2020-06-11 | ALL | v0.9.0 | Create examples in Powershell, of uploads and downloads of files using the SDK and exposed them in Github
2020-06-01 | ALL | v0.8.0 | SDK adapted to .Net Framework

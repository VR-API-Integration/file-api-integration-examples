# Changelog 
Date | Version Changes 
--- | --- 
2024-01-08| v2.1.0          VRFTR-5659: Remove unused dependencies  https://jira.visma.com/browse/VRFTR-5659
2023-02-20| v2.0.0          vrftr-6037 Rename Delete method.  Previous DeleteAsync method has been renamed to SetFileToDeletedAsync to avoid misunderstandings, as it doesn't delete files, it marks the file as 'deleted' for a subscriber.
2023-02-03| v1.22.0         Add deleted and deletedDate fields to list response.
2023-02-02| v1.21.0         Add subscriber delete documentation to the examples.
2023-02-02| v1.20.0         Breaking changes: IService includes a new method. Add delete method to SDK. This allows a subscriber to mark a file as deleted, won't delete the file.
2022-09-23| v1.19.0         Add count to concurrentQueue  ConcurrentQueue didn't have any way to retrieve the capacity, now the elements and unprocessed elements count can be retrieved.
2022-03-07| v1.18.0         Add copyright to the packages  Add Copyright © 2021 Visma to all projects - vrftr-3995
2022-01-18| v1.17.0         Internal updates  RaetMangedDefault pool is deprecated. We migrated it to CentralManagedCIWin.  - vrftr-3908
2022-01-11| v1.16.0         Internal updates
2022-01-11| v1.15.0         Internal updates to improve reliability  In order to be able to do a rollback with a tagged version, we did some modifications in the pipeline.
2021-10-11| v1.14.0         Internal Updates  Fixed medium and low Issues created by Polaris VRFTR-3184 VRFTR-3293
2021-10-08| v1.13.0         Update vulnerable packages reported by Snyk  Update vulnerable packages reported by Snyk  - vrftr-3279
2021-10-07| v1.12.0         Update vulnerable packages reported by Snyk  Update vulnerable packages reported by Snyk  - vrftr-3279
2021-10-01| v1.11.0         Upgrade .NET Core version to 3.1  We were using .NET Core 2.2. That version is out of support, so we upgraded it to .NET Core 3.1.  - vrftr-3412
2021-08-20| v1.10.0         Implementation of HasSubscription method
2021-08-20| v1.9.0          Internal updates  Internal updates vrftr-2640
2021-08-10| v1.8.0          Internal updates
2021-06-07| v1.7.0          Added documentation for HasSubscribers method
2021-06-04| v1.6.0          Fixed pipeline step to upload libraries to GitHub
2021-06-04| v1.5.0          Created nonfunctional method to check if a business type has subscription for a specific tenant
2021-05-12| v1.4.0          Minor pipeline improvements
2021-05-12| v1.3.0          Fix version issue in nuget.org
2021-05-11| v1.2.0          Run Polaris only on schedule
2021-03-11| v1.1.0          Improve pipeline to publish changelog to the example repository
2021-03-04| v1.0.0          Package is now deployed to Nuget
2021-02-18| v0.24.0         Security changes related to Dependency Confusion Vulnerability are implemented
2020-11-16| v0.23.0         Added pipeline retention for releases  Retain pipeline data when release reach REL stage
2020-10-10| v0.22.0         Update SonarQube Service Connection
2020-09-17| v0.21.0         Fixed nuget packages publishing issues
2020-09-09| v0.20.0         QA improvements
2020-08-25| v0.19.0         Fixed incomplete upload of big files when the connection is too slow
2020-07-29| v0.18.0         Added underlying http requests retrying
2020-07-21| v0.17.0         Remove ClientBufferSize, support for files longer than 2Gb  Remove ClientBufferSize, support for files longer than 2Gb
2020-07-21| v0.16.0         Solved a bug where big files (8 MB) might be uploaded corrupted.
2020-07-15| v0.15.0         Added HttpClient buffer size configuration options
2020-07-10| v0.14.0         Compatibility with .Net 4.5. Fixed some bugs. Improved responses.
2020-07-09| v0.13.0         Added timeout to download big files
2020-07-07| v0.12.0         Updates for download files to multiple folders
2020-06-16| v0.11.0         Adapt SDK for.Net Framework
2020-06-15| v0.10.0         Create documentation and deliver examples of uploads and downloads of files using .Net SDK
2020-06-11| v0.9.0          Create examples in Powershell, of uploads and downloads of files using the SDK and exposed them in Github
2020-06-01| v0.8.0          SDK adapted to .Net Framework

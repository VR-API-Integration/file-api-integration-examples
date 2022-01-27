# File API Curl Examples

**curl** folder includes a collection of examples that show how to integrate the **File API** with **Curl scripts**.

## Getting Started 

Download **curl** folder.

Inside the folder there is a batch file called **DownloadFiles.bat** which can be used to download a file from File API.

## Running Examples

1. Configure the files that are going to be downloaded (please see the remarks in **DownloadFiles.bat**).
Set the source file id and destination file name with the next schema:
#FirstFileId#FirstFileName#SecondFileId#SecondFileName

2. Enter the credentials (client id, client secret, tenant id).

3. Enter the path where you want to download the files.

Then the batch file will retrieve authentication token and download the files in the specified path with specified file names. 


## Authors

**Visma - Transporters Team**

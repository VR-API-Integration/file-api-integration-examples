@echo off & setlocal
setlocal enableDelayedExpansion

echo ================================================
echo File API example: Download files.
echo ================================================

REM Configure the files that are going to be downloaded.

REM The files are set with the next schema:
REM #FirstFileId#FirstFileName#SecondFileId#SecondFileName
REM e.g.
REM #26bb73c3-4135-4760-9e82-2d7c448caa24#payments.xml#d4176e36-ea64-4edf-b942-de5d9314a582#employees.yml
REM
REM To separe the files in different lines (for visual purpose only), write the character ^ at the end of all the lines but the last one.
REM #FirstFileId#FirstFileName^
REM #SecondFileId#SecondFileName
REM e.g.
REM #26bb73c3-4135-4760-9e82-2d7c448caa24#payments.xml^
REM #d4176e36-ea64-4edf-b942-de5d9314a582#employees.yml
set files=#fileId#fileName

REM Ask for the rest of configurations.

echo Enter your application's API Key.
echo (it can be retrieved from your application in the Developer Portal, under the name API Key)
set /p "_clientId="

echo Enter your application's Secret Key.
echo (it can be retrieved from your application in the Developer Portal, under the name Secret Key)
set /p "_clientSecret=Client secret: "

echo Enter your application's tenant ID.
set /p "_tenantId=Tenant ID: "

echo Enter the folder path where you want to download the files (e.g. C:/Visma/File API/Download):
set /p "_basePath="

if not "%_basePath:~-1%" == "/" if not "%_basePath:~-1%" == "\" set _basePath=%_basePath%\

REM Internal configuration.
set "_authTokenApiBaseUrl=https://api.raet.com/authentication"
set "_fileApiBaseUrl=https://api.raet.com/mft/v1.0"

REM Retrieve the authentication token.
echo Retrieving the authentication token...

for /f "delims=" %%i in (' ^
curl POST "%_authTokenApiBaseUrl%/token" ^
--header "Content-Type: application/x-www-form-urlencoded" ^
--header "Cache-Control: no-cache" ^
--data "grant_type=client_credentials&client_id=%_clientId%&client_secret=%_clientSecret%" ^
--silent ^
') do set _authTokenResponse=%%i

set "_beforeTokenKey=%_authTokenResponse:"access_token":"=" & set "_afterTokenKey=%"
set "_token=%_afterTokenKey:"=" & set "_afterToken=%"

echo Authentication token retrieved.

REM Download the files
echo Calling the 'download' endpoint...
:downloadFile

for /F "tokens=1,2 delims=#" %%G in ("%_files%") do (set "_fileId=%%G" & set "_fileName=%%H")
set _filePath=%_basePath%%_fileName%

echo.
echo Downloading file ^<%_fileId%^> to %_filePath%

curl %_fileApiBaseUrl%/files/%_fileId%?role=subscriber ^
--header "x-raet-tenant-id: %_tenantId%" ^
--header "Authorization: Bearer %_token%" ^
--header "Accept: application/octet-stream" ^
--output "%_filePath%"

echo File ^<%_fileId%^> was downloaded.

REM Remove the downloaded file from the list.
set "_files=!_files:#%_fileId%#%_fileName%=!"

if defined _files goto :downloadFile

echo ------------------------------------------------
echo You can find all downloaded files in %_basePath%
echo ------------------------------------------------

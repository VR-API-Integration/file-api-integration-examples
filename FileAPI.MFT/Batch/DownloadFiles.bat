@echo off & setlocal
setlocal enableDelayedExpansion

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

echo Enter your credentials.
set /p "clientId=Cliend ID: "
set /p "clientSecret=Client secret: "
set /p "tenantId=Tenant ID: "

echo.
echo Enter the path where you want to download the files:
set /p "basePath="

if not "%basePath:~-1%" == "/" if not "%basePath:~-1%" == "\" set basePath=%basePath%\

REM Retrieve authentication token

for /f %%i in (' ^
curl -s -X POST https://api.raet.com/authentication/token ^
-H "Content-Type: application/x-www-form-urlencoded" ^
-H "Cache-Control: no-cache" ^
-d "grant_type=client_credentials&client_id=%clientId%&client_secret=%clientSecret%" ^
') do set response=%%i

set "beforeTokenKey=%response:"access_token":"=" & set "afterTokenKey=%"
set "token=%afterTokenKey:"=" & set "afterToken=%"

REM Download the files

:download_file

for /F "tokens=1,2 delims=#" %%G in ("%files%") do (set "fileId=%%G" & set "fileName=%%H")
set filePath=%basePath%%fileName%

echo.
echo Downloading file ^<%fileId%^> to %filePath%

curl https://api.raet.com/mft/v1.0/files/%fileId%?role=subscriber ^
--header "x-raet-tenant-id: %tenantId%" ^
--header "Authorization: Bearer %token%" ^
-H "Accept: application/octet-stream" ^
--output "%filePath%"

echo File was downloaded.

REM Remove the downloaded file from the list.
set "files=!files:#%fileId%#%fileName%=!"

if defined files goto :download_file

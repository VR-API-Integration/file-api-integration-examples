@echo off & setlocal
setlocal enableDelayedExpansion

REM This example shows how to call the 'list' endpoint of the File API in order to retrieve the information of all the available files to be downloaded.

echo ================================================
echo File API example: Listing available files.
echo ================================================

REM User configuration.
echo Enter your credentials.

set /p "_clientId=Cliend ID: "
set /p "_clientSecret=Client secret: "
set /p "_tenantId=Tenant ID: "

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

REM List the files.
echo Calling the 'list' endpoint...

for /f "delims=" %%i in (' ^
curl GET "%_fileApiBaseUrl%/files?role=subscriber" ^
--header "x-raet-tenant-id: %_tenantId%" ^
--header "Authorization: Bearer %_token%" ^
--silent ^
') do set _listResponse=%%i

echo List of available files:
echo ------------------------------------------------
echo %_listResponse%
echo ------------------------------------------------
echo Tip: In order to download a file, call the 'download' endpoint with the desired fileId shown in the list above.

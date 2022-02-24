# This example shows how to call the 'list' endpoint of the File API with filters in order to retrieve the information of the specified files

Write-Host "================================================"
Write-Host "File API example: Listing filtered files."
Write-Host "================================================"

#region User_configuration

Write-Host "Enter your application's API Key."
Write-Host "(it can be retrieved from your application in the Developer Portal, under the name API Key)"
$clientId = Read-Host

Write-Host "Enter your application's Secret Key."
Write-Host "(it can be retrieved from your application in the Developer Portal, under the name Secret Key)"
$clientSecret = Read-Host

Write-Host "Enter your application's tenant ID."
$tenantId = Read-Host

#region List_filter

# Here you can find a a lot of examples for filtering the files.
# In order to use any of the filters, just uncomment (remove the hashtag #) of the desired filter and comment (add a hastag #) the rest.
# You can also create your own filter. Check the File API documentation to see all the available filters.

# Files already downloaded.
$filter = "status eq 'downloaded'"

# Files already downloaded that have the file type 7100.
#$filter = "status eq 'downloaded' and businessType eq 7100"

# Files downloaded and not downloaded (all) that have the file type 7100 or 7101.
#$filter = "status eq 'all' and (businessType eq 7100 or businessType eq 7101)"

# Files uploaded after the day 2022-02-15 at 16:42:30.
#$filter = "uploadDate gt 2022-02-15T16:42:30.000Z"

# Files uploaded after the day 2022-02-15 at 16:42:30 and before the day 2022-06-10 at 00:00:00.
#$filter = "uploadDate gt 2022-02-15T16:42:30.000Z and uploadDate lt 2022-06-10T00:00:00.000Z"

# Files of the file type 7100.
#$filter = "businessType eq 7100"

# Files of the file type 7100 or 7101.
#$filter = "businessType eq 7100 or businessType eq 7101"

# Files whith names that start with 'employee_profile'.
#$filter = "startsWith(FileName, 'employee_profile')"

# Files whith names that don't start with 'employee_profile'. 
#$filter = "startsWith(FileName, 'employee_profile') eq false"

# Files whith names that contains the word 'profile'.
#$filter = "contains(FileName, 'profile')"

# Files with .txt extension
#$filter = "endsWith(FileName, '.txt')"

Write-Host "Using the filter <$($filter)>."
Write-Host "If you want to change this filter, open the example in a text editor (like notepad) and follow the instructions under the 'List_filter' region."

#endregion

#endregion

#region Internal_configuration

$authTokenApiBaseUrl = "https://api.raet.com/authentication"
$fileApiBaseUrl = "https://api.raet.com/mft/v1.0"

#endregion

#region Retrieve_authentication_token

Write-Host "Retrieving the authentication token..."

$authHeaders = @{
    "Content-Type"  = "application/x-www-form-urlencoded";
    "Cache-Control" = "no-cache";
}
$authBody = @{
    "grant_type"    = "client_credentials";
    "client_id"     = $clientId;
    "client_secret" = $clientSecret;
}

$authTokenResponse = Invoke-RestMethod -Method "Post" -Uri "$($authTokenApiBaseUrl)/token" -Headers $authHeaders -Body $authBody
$token = $authTokenResponse.access_token

Write-Host "Authentication token retrieved."

#endregion

#region List_files

Write-Host "Calling the 'list' endpoint..."

$listHeaders = @{
    "x-raet-tenant-id" = $tenantId;
    "Authorization"    = "Bearer $($token)";
}
$listBody = @{
    '$filter' = $filter;
}

$listResponse = Invoke-RestMethod -Method "Get" -Uri "$($fileApiBaseUrl)/files?role=subscriber" -Headers $listHeaders -Body $listBody

Write-Host "List of files filtered by <$($filter)>:"
Write-Host "------------------------------------------------"
$listResponse | ConvertTo-Json -Depth 10
Write-Host "------------------------------------------------"
Write-Host "Tip: In order to download a file, call the 'download' endpoint with the desired fileId shown in the list above."

#endregion

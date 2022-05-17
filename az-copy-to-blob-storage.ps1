
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SITE_NAME,
    [Parameter(Mandatory = $true)]
    [string]$ENVIRONMENT,
    [Parameter(Mandatory = $true)]
    [string]$STORAGE_ACCOUNT,
    [Parameter(Mandatory = $true)]
    [string]$RELEASE_ZIP_FILE_PATH
)
Expand-Archive $RELEASE_ZIP_FILE_PATH ./drop;
$containerName = "$SITE_NAME-$ENVIRONMENT"
$container= az storage container exists -n $containerName --account-name $STORAGE_ACCOUNT --auth-mode key | ConvertFrom-Json
if ($container.exists -ne $true) {
    az storage container create -n $containerName --public-access blob --account-name $STORAGE_ACCOUNT --auth-mode key;
}
az storage blob upload-batch -d $containerName --account-name $STORAGE_ACCOUNT -s ./drop --pattern *.* --auth-mode key --overwrite;

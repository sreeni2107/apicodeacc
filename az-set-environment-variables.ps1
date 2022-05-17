[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$RESOURCE_GROUP,
    [Parameter(Mandatory = $true)]
    [string]$SITE_NAME,
    [Parameter(Mandatory = $true)]
    [string]$ENVIRONMENT,
    [Parameter(Mandatory = $true)]
    [string]$REGION
)
$prefix = "APPSETTING_"
Get-Item -Path Env:* | ForEach-Object { if ($_.Name.StartsWith($prefix)) {
        $key = $_.Name.Replace($prefix, "");
        $value = $_.Value.ToString()
        $setting = $key + "=" + $value
        az webapp config appsettings set --resource-group $RESOURCE_GROUP `
            --name $SITE_NAME-$ENVIRONMENT-$REGION `
            --settings $setting `
            --slot staging
    } }

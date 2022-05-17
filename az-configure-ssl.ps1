# az-configure-ssl <resource-group-name> <site-name> <environment-name>
# Assumes that an active auth context is established and the target subscription has been selected.
# Creates:
# Will error if the account exists and is not availble to the established auth context
# The scipt with complete without errors if the accounts exist
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$RESOURCE_GROUP,
    [Parameter(Mandatory = $true)]
    [string]$SITE_NAME,
    [Parameter(Mandatory = $true)]
    [string]$ENVIRONMENT,
    [Parameter(Mandatory = $true)]
    [string]$REGION,
    [Parameter(Mandatory = $true)]
    [string]$CERT_SECRET_NAME,
    [Parameter(Mandatory = $true)]
    [string]$KEY_VAULT_NAME,
    [Parameter(Mandatory = $true)]
    [string]$FQDN,
    [Parameter(Mandatory = $true)]
    [string]$servicePrincipalId,
    [Parameter(Mandatory = $true)]
    [string]$servicePrincipalKey,
    [Parameter(Mandatory = $true)]
    [string]$tenantId
)
# Quit on error
$ErrorActionPreference = "Stop"

# Login....
az login --service-principal -u $servicePrincipalId -p $servicePrincipalKey --tenant $tenantId

Remove-Item *.pfx
$DASHED_NAME = ($SITE_NAME + "-" + $ENVIRONMENT).toLower();

$LOCATION = $REGION.Replace(" ", "").ToLower()

$APP_SERVICE_NAME = ($DASHED_NAME + "-" + $LOCATION)

if ($DASHED_NAME.Length -lt 8 -or $DASHED_NAME.Length -gt 24) {
    throw "The environment name must be between 8 and 24 characters"
}

if ($FQDN.Length -gt 4 -and ($CERT_SECRET_NAME -lt 1 -or $KEY_VAULT_NAME -lt 1 )) {
    throw "When using a fully qualified domain a cert is required"
}

function set_custom_hostname {
    $customDomain = $FQDN
    # Bind custom host name to site
    $boundList = az webapp config hostname list --resource-group $RESOURCE_GROUP `
        --webapp-name $APP_SERVICE_NAME `
        --query "[?name=='$customDomain']" | ConvertFrom-Json
    if ($boundList.Length -eq 0) {
        Write-Host "Binding custom host name to site"
        az webapp config hostname add --hostname $customDomain `
            --resource-group $RESOURCE_GROUP `
            --webapp-name $APP_SERVICE_NAME
    }
    Write-Host "$customDomain bound to $APP_SERVICE_NAME"
}

function upload_ssl {
    # Download the cert from keyvault
    az keyvault secret download --name $CERT_SECRET_NAME `
								--vault-name $KEY_VAULT_NAME `
								--file temp.pfx
    # Generated a one time use password
    $pfxPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | ForEach-Object { [char]$_ })
    # Read the downloaded file into a byte array.
    $pfxPath = (Get-Item -Path ".\temp.pfx").FullName
    # Use an X509Certificate2 object to import and export with a password
    $bytes = [Convert]::FromBase64String([System.IO.File]::ReadAllText($pfxPath))
    $pfxCertObject = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
    $exported = $pfxCertObject.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $pfxPassword)
    # Write the exported cert to disk.
    $exportPath = Join-Path (Get-Item -Path ".\").FullName "exported.pfx"
    [System.IO.File]::WriteAllBytes($exportPath, $exported)
    # Upload the cert to the webapp
    $ssl = az webapp config ssl upload --certificate-file $exportPath `
								--certificate-password $pfxPassword `
								--name $APP_SERVICE_NAME `
								--resource-group $RESOURCE_GROUP | ConvertFrom-Json
    return $ssl
}

function bind_ssl {
    $ssl = upload_ssl
    Write-Host "Binding SSL cert to $APP_SERVICE_NAME"
    az webapp config ssl bind --certificate-thumbprint $ssl.thumbprint `
        --ssl-type SNI `
        --name $APP_SERVICE_NAME `
        --resource-group $RESOURCE_GROUP
    Write-Host "SSL bound for $APP_SERVICE_NAME"

    az webapp update `
    --name $APP_SERVICE_NAME `
    --resource-group $RESOURCE_GROUP `
    --https-only true

    az webapp config set `
        --name $APP_SERVICE_NAME `
        --resource-group $RESOURCE_GROUP `
        --min-tls-version 1.2
}


set_custom_hostname
bind_ssl

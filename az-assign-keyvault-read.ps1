[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$RESOURCE_GROUP,
    [Parameter(Mandatory = $true)]
    [string]$SITE_NAME,
    [Parameter(Mandatory = $true)]
    [string]$SHARED_KEY_VAULT,
    [Parameter(Mandatory = $true)]
    [string]$EVENTS_KEY_VAULT
)

# assign a managed identity to the site & give it access to read KeyVault Secrets
$principal = az webapp identity assign --resource-group $RESOURCE_GROUP --name $SITE_NAME | Convert-FromJson
az keyvault set-policy --name $SHARED_KEY_VAULT --object-id $principal.principalId --secret-permissions get list

az keyvault set-policy --name $EVENTS_KEY_VAULT --object-id $principal.principalId --secret-permissions get list


$principal = az webapp identity assign --resource-group $RESOURCE_GROUP --name $SITE_NAME --slot staging | Convert-FromJson
az keyvault set-policy --name $SHARED_KEY_VAULT --object-id $principal.principalId --secret-permissions get list

az keyvault set-policy --name $EVENTS_KEY_VAULT --object-id $principal.principalId --secret-permissions get list

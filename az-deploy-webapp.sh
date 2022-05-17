#!/bin/bash
#
# az-create-appservice-deployment
# Assumes that an active auth context is established and the target subscription has been selected.
# Assumes that a traffic manager with the dns name web-<site-name>-<environment-name>.trafficmanager.net exists

if [ $# -lt 8 ]; then
  echo "usage: az-create-appservice-deployment <resource-group-name> <site-name> <environment-name> <location> <zipfile> <runtime> <keyvault> <dns-name> <cert-name> <region-count>"
  exit 1
fi

RESOURCE_GROUP=$1
MANAGER_NAME=$2-$3
LOCATION=$4
PLAN_NAME=$MANAGER_NAME-$LOCATION-plan
[[ $PLAN_NAME == api-* ]] && PLAN_NAME=${PLAN_NAME:4}
SITE_NAME=$MANAGER_NAME-$LOCATION
ZIP_FILE=$5
RUNTIME=$6
KEYVAULT=$7
DNS_NAME=$8
CERT_NAME=$9
REGION_COUNT=${10}
[ $REGION_COUNT ] || REGION_COUNT=0

# ensure there is a plan
plans=$(az appservice plan list --query "[?name=='$PLAN_NAME']")
if [ $(echo $plans | jq 'length') = 0 ]; then
    # need to create a plan
    az appservice plan create --name $PLAN_NAME \
                                --resource-group $RESOURCE_GROUP \
                                --is-linux \
                                --location $LOCATION \
                                --sku S1
fi

# ensure there is a webapp
webapps=$(az webapp list --query "[?name=='$SITE_NAME']")
if [ $(echo $webapps | jq 'length') = 0 ]; then
    # create the webapp
    az webapp create --resource-group $RESOURCE_GROUP \
                        --plan $PLAN_NAME \
                        --runtime $RUNTIME \
                        --name $SITE_NAME
    # assign a managed identity to the site & give it access to read KeyVault Secrets
    principalId=$(az webapp identity assign --resource-group $RESOURCE_GROUP --name $SITE_NAME | jq -r '.principalId')
    az keyvault set-policy --name $KEYVAULT --object-id $principalId --secret-permissions get list
fi
# ensure there is a staging slot
slots=$(az webapp deployment slot list --resource-group $RESOURCE_GROUP --name $SITE_NAME)
if [ $(echo $slots | jq 'length') = 0 ]; then
    # create the staging slot
    az webapp deployment slot create --resource-group $RESOURCE_GROUP \
                        --name $SITE_NAME \
                        --slot staging
    # assign a managed identity to the site & give it access to read KeyVault Secrets
    principalId=$(az webapp identity assign --resource-group $RESOURCE_GROUP --name $SITE_NAME --slot staging | jq -r '.principalId')
    az keyvault set-policy --name $KEYVAULT --object-id $principalId --secret-permissions get list


    # Set up the slot to build the site from the zip
    echo 'az webapp config appsettings set --resource-group $RESOURCE_GROUP --slot staging --name $SITE_NAME --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true'
    az webapp config appsettings set --resource-group $RESOURCE_GROUP \
                                    --name $SITE_NAME \
                                    --slot staging \
                                    --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true
fi

# deploy the code
az webapp deployment source config-zip --resource-group $RESOURCE_GROUP \
                                        --name $SITE_NAME \
                                        --slot staging \
                                        --src $ZIP_FILE

# if only have one region then there's no traffic manager enrollment
if [ $REGION_COUNT -gt 1 ]; then
    webapp_id=$(echo $(az webapp show --resource-group $RESOURCE_GROUP --name $SITE_NAME --query id) | jq -r .)
    # enroll in traffic manager
    endpoints=$(az network traffic-manager endpoint list --profile-name $MANAGER_NAME \
                                                --resource-group $RESOURCE_GROUP \
                                                --type azureEndpoints \
                                                --query "[?targetResourceId=='$webapp_id']")
    # is the webapp already enrolled?
    if [ $(echo $endpoints | jq 'length') = 0 ]; then
        # no - enroll it
        az network traffic-manager endpoint create --resource-group $RESOURCE_GROUP \
                                                    --profile-name $MANAGER_NAME \
                                                    --name $SITE_NAME \
                                                    --type azureEndpoints \
                                                    --target-resource-id $webapp_id \
                                                    --endpoint-status enabled
    fi
fi

# bind the domain name.
if [ $DNS_NAME ]; then
    # Bind custom host name to site
    boundList=$(az webapp config hostname list --resource-group $RESOURCE_GROUP \
                                                --webapp-name $SITE_NAME \
                                                --query "[?name=='$DNS_NAME']" | jq -r .)
    if [ $(echo $boundList | jq 'length') -eq 0 ]; then
        echo "Binding custom host name to site"
        az webapp config hostname add --hostname $DNS_NAME \
                                        --resource-group $RESOURCE_GROUP \
                                        --webapp-name $SITE_NAME
        echo "$DNS_NAME bound to $SITE_NAME"
    fi
fi

# bind the SSL cert in KeyVault
#
# This command doesn't yet work if the KeyVault and WebApp are in separate resource groups
# Leaving here in the hope that one day this will be fixed
#
# if [ $CERT_NAME ]; then
#     az webapp config ssl import --resource-group $RESOURCE_GROUP \
#                                 --name $SITE_NAME \
#                                 --key-vault $KEYVAULT \
#                                 --key-vault-certificate-name $CERT_NAME

# fi

# CDN backing?

# # Echo the authentication detail out to variables for use in a PowerShell step
# echo "##vso[task.setVariable variable=servicePrincipalId]$servicePrincipalId"
# echo "##vso[task.setVariable variable=servicePrincipalKey]$servicePrincipalKey "
# echo "##vso[task.setVariable variable=tenantId]$tenantId"


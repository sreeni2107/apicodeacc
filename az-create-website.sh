#!/bin/bash
#
# az-create-website
# Assumes that an active auth context is established and the target subscription has been selected.
# Creates a storage account with the name <site-name><environment-name>
# Performs checks to ensure that if the storage account already exists no create actions are taken
# Will error if the account exsits and is not availble to the established auth context
# Adds CDN support to the site

if [ $# -lt 3 ]; then
  echo "usage: az-create-website <resource-group-name> <site-name> <environment-name> [dns-zone]"
  exit
fi

RESOURCE_GROUP=$1
DASHED_NAME=$2-$3
STORAGE_NAME=$(echo "$DASHED_NAME" | tr -d - | tr '[:upper:]' '[:lower:]')
echo "Creating and configuring $STORAGE_NAME in $RESOURCE_GROUP"

CREATE_STORAGE=$(az storage account check-name --name $STORAGE_NAME | jq -r '.nameAvailable')

echo $CREATE_STORAGE
if [ $CREATE_STORAGE = true ]; then
  echo "Create the account"
  az storage account create \
    --resource-group $RESOURCE_GROUP \
    --name $STORAGE_NAME \
    --access-tier Hot \
    --kind StorageV2 \
    --sku Standard_GRS
else
  echo "Account exists"
fi
# get the extension to set up static websites.
az extension add --name storage-preview
# setup the static sites feature
az storage blob service-properties update \
  --account-name $STORAGE_NAME \
  --static-website \
  --404-document index.html \
  --index-document index.html

# VSO Hooks to pass out variables for use in downstream scripts
echo "##vso[task.setvariable variable=storage-account-name]$STORAGE_NAME"
KEY=$(az storage account keys list --account-name $STORAGE_NAME --resource-group $RESOURCE_GROUP | jq -r '.[0] | .value')
echo $KEY
echo "##vso[task.setvariable variable=storage-account-key]$KEY"

ORIGIN=$(az storage account show --name $STORAGE_NAME --resource-group $RESOURCE_GROUP --query "primaryEndpoints.web" --output tsv | cut -d '/' -f 3)

CREATE_CDN=$(az cdn name-exists --name $DASHED_NAME | jq -r '.nameAvailable')
if [ $CREATE_CDN = true ]; then
  echo "Create the cdn"
  # Premium_Verizon is required to get the rule to force an HTTP -> HTTPS redirect
  az cdn profile create \
    --name $DASHED_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Premium_Verizon
  # Point the new endpoint at the custom origin for the static website
  az cdn endpoint create \
    --name $DASHED_NAME \
    --origin $ORIGIN \
    --resource-group $RESOURCE_GROUP \
    --profile-name $DASHED_NAME \
    --no-http true \
    --origin-host-header $ORIGIN
else
  echo "CDN exists"
fi

if [ ! -z $4 ]; then
    echo "DNS zone supplied"
    DNS_ZONE=$4
    # Configure DNS entry to point at the CDN endpoint.
    # DNS should point at CNS OR name as CNAME
    zones=$(az network dns zone list --query "[?name=='$DNS_ZONE']")
    zoneMatches=$(echo $zones | jq 'length')
    # if the zone exists
    if [ $zoneMatches = 1 ]; then
    zoneResourceGroup=$(echo $zones | jq -r '.[].resourceGroup')
    cnames=$(az network dns record-set cname list --resource-group $zoneResourceGroup \
                            --zone-name $DNS_ZONE \
                            --query "[?name=='$DASHED_NAME']")
    if [ $(echo $cnames | jq 'length') = 0 ]; then
        echo "Creating DNS entries"
        #create the cname entry.
        az network dns record-set cname create --name $DASHED_NAME \
                            --resource-group $zoneResourceGroup \
                            --zone-name $DNS_ZONE
    fi
    # Set the cannonical name for the CNAME
    az network dns record-set cname set-record --resource-group $zoneResourceGroup \
                            --zone-name $DNS_ZONE \
                            --cname "$DASHED_NAME.azureedge.net" \
                            --record-set-name $DASHED_NAME
    fi
fi

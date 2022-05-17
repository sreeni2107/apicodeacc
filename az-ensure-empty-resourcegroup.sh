#!/bin/bash
#
# az-ensure-resourcegroup
# Assumes that an active auth context is established and the target subscription has been selected.
# Ensures that a resource group with the supplied name exists
# If no location is provided then the resource group will be created in West US


if [ $# -lt 2 ]; then
  echo "usage: az-ensure-resourcegroup <resource-group-name> <location>"
  exit 1
fi

RESOURCE_GROUP=$1
LOCATION=$(echo "$2" | tr -d " " | tr '[:upper:]' '[:lower:]')

function ensure_group () {

  RESOURCE_GROUP_EXISTS=$(az group exists --name $RESOURCE_GROUP)
  if [ $RESOURCE_GROUP_EXISTS = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
  fi

}

# Ensure resource group exists
echo "Ensuring $RESOURCE_GROUP exists"
ensure_group
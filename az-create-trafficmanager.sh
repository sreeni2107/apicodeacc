#!/bin/bash
#
# az-create-trafficmanager
# Assumes that an active auth context is established and the target subscription has been selected.
# Creates a traffic manager with the dns name <site-name><environment-name>.trafficmanager.net if the dns name is available

if [ $# -lt 3 ]; then
  echo "usage: az-create-trafficmanager <resource-group-name> <site-name> <environment-name>"
  exit
fi

RESOURCE_GROUP=$1

MANAGER_NAME=web-$2-$3

CREATE_TRAFFIC_MANAGER=$(az network traffic-manager profile check-dns --name $MANAGER_NAME | jq -r '.nameAvailable')
if [ $CREATE_TRAFFIC_MANAGER = true ]; then
  # Create traffic manager.
  az network traffic-manager profile create --name $MANAGER_NAME \
                                          --resource-group $RESOURCE_GROUP \
                                          --routing-method Performance \
                                          --unique-dns-name $MANAGER_NAME \
                                          --protocol HTTPS \
                                          --path "/" \
                                          --port 443
fi

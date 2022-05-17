#!/bin/bash
#
# az-ensure-resourcegroup
# Assumes that an active auth context is established and the target subscription has been selected.
# Ensures that a resource group with the supplied name exists
# If no location is provided then the resource group will be created in West US


if [ $# -lt 4 ]; then
  echo "usage: az-ensure-resourcegroup <resource-group-name> <site-name> <environment-name> <location>"
  exit 1
fi

RESOURCE_GROUP=$1
DASHED_NAME="$2-$3"
[[ $DASHED_NAME == api-* ]] && DASHED_NAME=${DASHED_NAME:4}
LOCATION=$4

function ensure_group () {

  RESOURCE_GROUP_EXISTS=$(az group exists --name $RESOURCE_GROUP)
  if [ $RESOURCE_GROUP_EXISTS = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
  fi

}

function create_app_insights () {
  local CREATE=true
  for k in $(az resource list --resource-type "Microsoft.Insights/components" --query [].name | jq -r '.[]'); do
    if [ "$k" = $DASHED_NAME ]; then
      CREATE=false
      break
    fi
  done
  if [ $CREATE = true ]; then
    az resource create --name $DASHED_NAME \
                        --resource-group $RESOURCE_GROUP \
                        --resource-type "Microsoft.Insights/components" \
                        --location eastus \
                        --properties '{"ApplicationId":"$DASHED_NAME","Application_Type":"other"}'
	fi
	local insightsKey=$(az resource show --name $DASHED_NAME \
                                        --resource-group $RESOURCE_GROUP \
                                        --resource-type "Microsoft.Insights/components" \
                                        --query properties \
                                        | jq -r '.InstrumentationKey')
  export_variable "insightskey" $insightsKey
}
function export_variable() {
  echo "##vso[task.setVariable variable=$1;isOutput=true]$2"
}

# Ensure resource group exists
echo "Ensuring $RESOURCE_GROUP exists"
ensure_group
echo "Creating app insights"
create_app_insights

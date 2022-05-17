[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)]
	[string]$RESOURCE_GROUP,
	[Parameter(Mandatory=$true)]
	[string]$SUBSCRIPTION_NAME,
	[Parameter(Mandatory=$true)]
	[string]$SERVICEBUS_NAMESPACE,
	[Parameter(Mandatory=$true)]
	[string]$SERVICEBUS_TOPIC
)

Write-Host "Creating Service Bus Topic Subscriptions"
az servicebus topic subscription create --resource-group $RESOURCE_GROUP --namespace-name $SERVICEBUS_NAMESPACE --topic-name $SERVICEBUS_TOPIC --name $SUBSCRIPTION_NAME
Write-Host "Service bus subscription creation successful"
exit

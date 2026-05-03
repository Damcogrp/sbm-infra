// ============================================================
// modules/eventhub.bicep
// CAF names:
//   Namespace: evhns-sbm-{env}-cin
//   Hub:       evh-sbm-{env}-cin
// ============================================================

param location string
param base string
param throughputUnits int = 1
param partitionCount int = 2
param messageRetentionDays int = 7
param tags object

var eventHubNamespaceName = 'evhns-${base}'
var eventHubName          = 'evh-${base}'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: throughputUnits
  }
  properties: {
    isAutoInflateEnabled: false
    kafkaEnabled: false
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    partitionCount: partitionCount
    messageRetentionInDays: messageRetentionDays
  }
}

resource consumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01-preview' = {
  parent: eventHub
  name: 'cg-${base}-be'
  properties: {}
}

output eventHubNamespaceId string = eventHubNamespace.id
output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output eventHubConnectionString string = eventHubNamespace.listKeys('RootManageSharedAccessKey').primaryConnectionString

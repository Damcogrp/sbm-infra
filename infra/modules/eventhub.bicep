// ============================================================
// modules/eventhub.bicep — Production Standard
// CAF names:
//   Namespace: evhns-sbm-{env}-cin
//   Hub:       evh-sbm-{env}-cin
// SECURITY: Uses a dedicated SAS policy (Send+Listen) instead
//   of the built-in RootManageSharedAccessKey (full admin).
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('Throughput units for the namespace')
param throughputUnits int = 1

@description('Number of partitions per event hub')
param partitionCount int = 2

@description('Message retention in days')
param messageRetentionDays int = 7

param tags object

var eventHubNamespaceName = 'evhns-${base}'
var eventHubName          = 'evh-${base}'
var sasRuleName           = 'app-send-listen'

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
    minimumTlsVersion: '1.2'
    disableLocalAuth: false
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

resource appSasRule 'Microsoft.EventHub/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: sasRuleName
  properties: {
    rights: [
      'Send'
      'Listen'
    ]
  }
}

// ── Outputs ──
output eventHubNamespaceId string = eventHubNamespace.id
output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output eventHubConnectionString string = appSasRule.listKeys().primaryConnectionString

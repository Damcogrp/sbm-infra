// ============================================================
// modules/storage.bicep — Production Standard
// CAF name: stsbm{env}cin  (no hyphens — Azure storage rule)
// Max 24 chars, lowercase only
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('Storage account replication SKU')
param storageSku string = 'Standard_LRS'

param tags object

var storageAccountName = toLower(take(replace('st${base}', '-', ''), 24))

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: storageSku }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

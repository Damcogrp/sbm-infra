// ============================================================
// modules/storage.bicep
// CAF name: stsbm{env}cin  (no hyphens — Azure storage rule)
// Max 24 chars, lowercase only
// ============================================================

param location string
param projectName string
param environment string
param regionShort string
param storageSku string = 'Standard_LRS'
param tags object

var storageAccountName = toLower(take('st${projectName}${environment}${regionShort}', 24))

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
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

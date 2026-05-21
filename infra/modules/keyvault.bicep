// ============================================================
// modules/keyvault.bicep
// Point 4: 45-day secret expiry
// Point 5: IP address association
// CAF name: kv-sbm-{env}-cin-02
// Note: -02 suffix added to avoid soft-delete conflict
// ============================================================

param location string
param base string
param tags object
param secretExpiryDays int = 45
param softDeleteRetentionDays int = 7
param allowedIpAddresses array = []

var keyVaultName = 'kv-${base}-02'   // ← -02 suffix to avoid soft-delete conflict

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: true
    enableRbacAuthorization: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpAddresses: {
        value: ip
      }]
      virtualNetworkRules: []
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output secretExpiryDays int = secretExpiryDays

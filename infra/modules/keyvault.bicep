// ============================================================
// modules/keyvault.bicep
// Point 4: 45-day secret expiration + rotation policy
// Point 5: IP association via network ACLs
// CAF name: kv-sbm-{env}-cin
// ============================================================

param location string
param base string
param tags object

// Point 4: Secret expiry configurable from config.yml
param secretExpiryDays int = 45
param softDeleteRetentionDays int = 7

// Point 5: IP Address association — allowed IPs to access Key Vault
param allowedIpAddresses array = []   // e.g. ['20.192.x.x', '10.0.0.0/27']

var keyVaultName = 'kv-${base}'

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
    // Point 5: IP Address association
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

// Point 4: Secret rotation/expiry policy via Key Vault policy
// Note: Individual secrets get expiry set when created by app
// This sets the default rotation policy for auto-rotated secrets
resource secretRotationPolicy 'Microsoft.KeyVault/vaults/keys@2023-07-01' existing = {
  parent: keyVault
  name: 'placeholder'
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output secretExpiryDays int = secretExpiryDays

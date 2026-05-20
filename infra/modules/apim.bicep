// ============================================================
// modules/apim.bicep
// Azure API Management — Edge layer for all API traffic
// SKU: Developer (dev/qa), Standard (prod)
// CAF name: apim-sbm-{env}-cin
// Note: APIM deployment takes 30-45 minutes
// ============================================================

param location string
param base string
param environment string
param publisherEmail string
param publisherName string
param tags object

var apimName = 'apim-${base}'

// Developer tier for non-prod (no SLA but cost-effective)
// Standard tier for prod (SLA, VNet support)
var apimSku      = environment == 'prod' ? 'Standard' : 'Developer'
var apimCapacity = 1

resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSku
    capacity: apimCapacity
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────
output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimPortalUrl string = apim.properties.developerPortalUrl
output apimPrincipalId string = apim.identity.principalId

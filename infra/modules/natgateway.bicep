// ============================================================
// modules/natgateway.bicep
// Provides a static outbound public IP for the backend App Service
// Use case: Backend communicates with client's on-prem DB2
//           Client whitelists this IP — survives app service restarts
// CAF names:
//   Public IP:   pip-sbm-{env}-cin-nat
//   NAT Gateway: natgw-sbm-{env}-cin
// ============================================================

param location string
param base string
param tags object

var pipName   = 'pip-${base}-nat'
var natGwName = 'natgw-${base}'

// ── Static Public IP ──────────────────────────────────────────
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ── NAT Gateway ───────────────────────────────────────────────
resource natGateway 'Microsoft.Network/natGateways@2023-04-01' = {
  name: natGwName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIpAddresses: [ { id: publicIp.id } ]
    idleTimeoutInMinutes: 10
  }
}

// ── Outputs ───────────────────────────────────────────────────
output natGatewayId string = natGateway.id
output natGatewayName string = natGateway.name
output staticPublicIp string = publicIp.properties.ipAddress
output publicIpName string = publicIp.name

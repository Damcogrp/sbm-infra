// ============================================================
// modules/vnet.bicep
// CAF names:
//   VNet:        vnet-sbm-{env}-cin
//   NSG App:     nsg-sbm-{env}-cin-app
//   NSG Data:    nsg-sbm-{env}-cin-data
//   NSG Gateway: nsg-sbm-{env}-cin-gw   (only if deployAppGateway=true)
//   Subnet App:  snet-sbm-{env}-cin-app
//   Subnet Data: snet-sbm-{env}-cin-data
//   Subnet GW:   snet-sbm-{env}-cin-gw  (only if deployAppGateway=true)
// ============================================================

param location string
param base string
param vnetAddressPrefix string
param appSubnetPrefix string
param dataSubnetPrefix string
param gwSubnetPrefix string = '10.0.3.0/24'
param deployAppGateway bool = false
param natGatewayId string = ''
param tags object

var vnetName    = 'vnet-${base}'
var nsgAppName  = 'nsg-${base}-app'
var nsgDataName = 'nsg-${base}-data'
var nsgGwName   = 'nsg-${base}-gw'
var appSubnet   = 'snet-${base}-app'
var dataSubnet  = 'snet-${base}-data'
var gwSubnet    = 'snet-${base}-gw'

// ── NSG: App Subnet ───────────────────────────────────────────
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAppName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ── NSG: Data Subnet ──────────────────────────────────────────
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgDataName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SQL-From-AppSubnet'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
        }
      }
      {
        name: 'Allow-Redis-From-AppSubnet'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '6380'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ── NSG: Gateway Subnet (App Gateway requires specific rules) ─
resource nsgGw 'Microsoft.Network/networkSecurityGroups@2023-04-01' = if (deployAppGateway) {
  name: nsgGwName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGW-Infra'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// ── VNet ──────────────────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ vnetAddressPrefix ] }
    subnets: concat(
      [
        {
          name: appSubnet
          properties: {
            addressPrefix: appSubnetPrefix
            networkSecurityGroup: { id: nsgApp.id }
            natGateway: empty(natGatewayId) ? null : { id: natGatewayId }
            delegations: [
              {
                name: 'appServiceDelegation'
                properties: { serviceName: 'Microsoft.Web/serverFarms' }
              }
            ]
          }
        }
        {
          name: dataSubnet
          properties: {
            addressPrefix: dataSubnetPrefix
            networkSecurityGroup: { id: nsgData.id }
            serviceEndpoints: [
              { service: 'Microsoft.Sql' }
              { service: 'Microsoft.Storage' }
              { service: 'Microsoft.KeyVault' }
            ]
          }
        }
      ],
      deployAppGateway ? [
        {
          name: gwSubnet
          properties: {
            addressPrefix: gwSubnetPrefix
            networkSecurityGroup: { id: nsgGw.id }
          }
        }
      ] : []
    )
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appSubnetId string = vnet.properties.subnets[0].id
output dataSubnetId string = vnet.properties.subnets[1].id
output gwSubnetId string = deployAppGateway ? vnet.properties.subnets[2].id : ''

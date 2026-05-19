// ============================================================
// modules/appgateway.bicep
// Azure Application Gateway — WAF v2, QA and Prod only
// Acts as reverse proxy + WAF in front of backend App Service
// CAF names:
//   Public IP:   pip-sbm-{env}-cin-agw
//   App Gateway: agw-sbm-{env}-cin
// ============================================================

param location string
param base string
param gatewaySubnetId string
param backendFqdn string
param tags object

var appGwName = 'agw-${base}'
var pipName   = 'pip-${base}-agw'

// ── Public IP for App Gateway ─────────────────────────────────
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

// ── Application Gateway WAF v2 ────────────────────────────────
resource appGateway 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: appGwName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 3
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: { id: gatewaySubnetId }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwFrontendIP'
        properties: {
          publicIPAddress: { id: publicIp.id }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-80'
        properties: { port: 80 }
      }
      {
        name: 'port-443'
        properties: { port: 443 }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {
          backendAddresses: [
            { fqdn: backendFqdn }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'backendHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGwName, 'healthProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Https'
          path: '/api/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'backendHttpSettings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────
output appGatewayId string = appGateway.id
output appGatewayName string = appGateway.name
output appGatewayPublicIp string = publicIp.properties.ipAddress
output appGatewayPublicIpName string = publicIp.name

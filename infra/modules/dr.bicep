// ============================================================
// modules/dr.bicep
// Disaster Recovery — Traffic Manager + SQL Failover Group
// Deployed only in PROD (deploy_dr: true in config.yml)
// CAF names:
//   Traffic Manager: tm-sbm-prod
//   SQL Failover:    fog-sbm-prod
// ============================================================

param base string
param tags object

// ── Primary region resources ──────────────────────────────────
param primaryLocation string
param primaryFrontendFqdn string
param primaryBackendFqdn string
param primarySqlServerId string
param primarySqlServerName string

// ── Secondary region resources ────────────────────────────────
param secondaryLocation string
param secondaryRegionShort string
param secondarySqlServerName string = ''

// ── Traffic Manager ───────────────────────────────────────────
// Routes users to primary, fails over to secondary automatically
var tmProfileName = 'tm-${base}'

resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: tmProfileName
  location: 'global'
  tags: tags
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'   // Primary = priority 1, Secondary = priority 2
    dnsConfig: {
      relativeName: tmProfileName
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/api/health'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
    }
    endpoints: [
      {
        name: 'primary-endpoint'
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          target: primaryFrontendFqdn
          endpointStatus: 'Enabled'
          priority: 1                  // Primary always serves traffic
        }
      }
    ]
  }
}

// ── SQL Failover Group ────────────────────────────────────────
// Automatically replicates SQL to secondary region
// Fails over automatically if primary SQL goes down
resource sqlFailoverGroup 'Microsoft.Sql/servers/failoverGroups@2022-05-01-preview' = if (!empty(secondarySqlServerName)) {
  name: '${primarySqlServerName}/fog-${base}'
  properties: {
    readWriteEndpoint: {
      failoverPolicy: 'Automatic'
      failoverWithDataLossGracePeriodMinutes: 60  // Wait 60 mins before auto-failover
    }
    readOnlyEndpoint: {
      failoverPolicy: 'Disabled'
    }
    partnerServers: [
      {
        id: resourceId('Microsoft.Sql/servers', secondarySqlServerName)
      }
    ]
  }
}

output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
output trafficManagerName string = trafficManager.name
output failoverGroupName string = !empty(secondarySqlServerName) ? 'fog-${base}' : 'SQL Failover not configured'

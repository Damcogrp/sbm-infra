// ============================================================
// modules/sql.bicep
// Point 6: SQL Private Endpoint — traffic only from backend
//          app service via data subnet (VNet service endpoint)
// CAF names:
//   SQL Server:   sql-sbm-{env}-cin
//   SQL Database: sqldb-sbm-{env}-cin
//   Private EP:   pe-sql-sbm-{env}-cin
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('SQL administrator login name')
param sqlAdminLogin string

@description('SQL administrator password — injected from GitHub Secret')
@secure()
param sqlAdminPassword string

@description('SQL Database SKU')
param sqlDatabaseSku string = 'S1'

@description('Data subnet ID — SQL private endpoint placed here')
param dataSubnetId string = ''

param tags object

var sqlServerName   = 'sql-${base}'
var sqlDatabaseName = 'sqldb-${base}'
var privateEndpointName = 'pe-sql-${base}'

// ── SQL Server ────────────────────────────────────────────────
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'    // ← Public access OFF — private endpoint only
  }
}

// ── SQL Database ──────────────────────────────────────────────
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: sqlDatabaseSku
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ── SQL Auditing ──────────────────────────────────────────────
resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2022-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
  }
}

// ── Private Endpoint — SQL only accessible from data subnet ──
// This is what ensures only backend app service can reach SQL
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (!empty(dataSubnetId)) {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: { id: dataSubnetId }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-conn'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
  }
}

// ── Private DNS Zone for SQL ──────────────────────────────────
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(dataSubnetId)) {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: tags
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(dataSubnetId)) {
  parent: privateEndpoint
  name: 'sqlDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
output privateEndpointId string = !empty(dataSubnetId) ? privateEndpoint.id : ''

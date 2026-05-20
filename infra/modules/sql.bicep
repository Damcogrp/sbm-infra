// ============================================================
// modules/sql.bicep — Production Standard
// CAF names:
//   SQL Server:   sql-sbm-{env}-cin
//   SQL Database: sqldb-sbm-{env}-cin
// SECURITY: Connection string is NOT output from this module.
//   main.bicep constructs it and stores it in Key Vault.
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('SQL administrator login name')
param sqlAdminLogin string

@description('SQL administrator password — injected from Key Vault')
@secure()
param sqlAdminPassword string

@description('SQL Database DTU-based SKU name (e.g. S0, S1, S2)')
param sqlDatabaseSku string = 'S1'

param tags object

var sqlServerName   = 'sql-${base}'
var sqlDatabaseName = 'sqldb-${base}'

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

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

resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2022-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
  }
}

// ── Outputs (safe — no secrets) ──
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name

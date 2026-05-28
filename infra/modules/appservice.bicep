// ============================================================
// modules/appservice.bicep
// Linux + Nginx hosting (changed from Windows + IIS)
// CAF names:
//   Plan:     asp-sbm-{env}-{region}
//   Frontend: app-sbm-{env}-{region}-fe  (Angular v21, Node 20)
//   Backend:  app-sbm-{env}-{region}-be  (.NET 8, Linux)
//   EventBus: func-sbm-{env}-{region}-evb (.NET 8 isolated, Linux)
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('Deployment environment label')
param environment string

@description('App Service Plan SKU name')
param appServicePlanSku string

@description('App Service Plan SKU tier')
param appServicePlanTier string

@description('Subnet resource ID for VNet integration')
param appSubnetId string

@description('Key Vault URI for app configuration')
param keyVaultUri string

param tags object

// ── App Insights ──────────────────────────────────────────────
param appInsightsFrontendKey string
param appInsightsFrontendConnStr string
param appInsightsBackendKey string
param appInsightsBackendConnStr string
param appInsightsFunctionKey string
param appInsightsFunctionConnStr string

// ── Connection strings ────────────────────────────────────────
@secure()
param redisConnectionString string

@secure()
param eventHubConnectionString string

param eventHubName string

@secure()
param storageConnectionString string

@secure()
param sqlConnectionString string

// ── Naming ────────────────────────────────────────────────────
var aspName     = 'asp-${base}'
var feAppName   = 'app-${base}-fe'
var beAppName   = 'app-${base}-be'
var funcAppName = 'func-${base}-evb'

// ── App Service Plan (Linux) ──────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: aspName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanTier
  }
  kind: 'linux'                // ← Linux (was 'app' for Windows)
  properties: {
    reserved: true             // ← required for Linux
  }
}

// ── Frontend App (Angular v21, Linux + Nginx) ─────────────────
resource frontendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: feAppName
  location: location
  kind: 'app,linux'            // ← Linux app
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'frontend', Stack: 'angular-v21', OS: 'linux', WebServer: 'nginx' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      linuxFxVersion: 'NODE|20-lts'    // ← Node 20 for Angular frontend
      appSettings: [
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsFrontendKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsFrontendConnStr }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
      ]
    }
  }
}

resource frontendVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: frontendApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── Backend App (.NET 8, Linux + Nginx) ───────────────────────
resource backendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: beAppName
  location: location
  kind: 'app,linux'            // ← Linux app
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'backend', Stack: 'dotnet-8', OS: 'linux', WebServer: 'nginx' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      alwaysOn: true
      healthCheckPath: '/api/health'
      linuxFxVersion: 'DOTNETCORE|8.0'  // ← .NET 8 on Linux
      appSettings: [
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsBackendKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsBackendConnStr }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
        { name: 'Redis__ConnectionString',               value: redisConnectionString }
        { name: 'EventHub__ConnectionString',            value: eventHubConnectionString }
        { name: 'EventHub__Name',                        value: eventHubName }
      ]
      connectionStrings: [
        {
          name: 'SqlConnection'
          connectionString: sqlConnectionString
          type: 'SQLAzure'
        }
      ]
    }
  }
}

resource backendVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: backendApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── EventBus Function App (Linux, .NET 8 isolated) ───────────
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp,linux'    // ← Linux function app
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'eventbus', Stack: 'dotnet-functions-v4', OS: 'linux' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'  // ← .NET 8 isolated on Linux
      appSettings: [
        { name: 'AzureWebJobsStorage',                   value: storageConnectionString }
        { name: 'FUNCTIONS_EXTENSION_VERSION',           value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME',              value: 'dotnet-isolated' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsFunctionKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsFunctionConnStr }
        { name: 'EventHubConnection',                    value: eventHubConnectionString }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
      ]
    }
  }
}

resource functionVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── Outputs ───────────────────────────────────────────────────
output appServicePlanId string = appServicePlan.id
output frontendAppUrl string = 'https://${frontendApp.properties.defaultHostName}'
output backendAppUrl string = 'https://${backendApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output backendAppFqdn string = backendApp.properties.defaultHostName
output frontendAppName string = frontendApp.name
output backendAppName string = backendApp.name
output functionAppName string = functionApp.name
output frontendPrincipalId string = frontendApp.identity.principalId
output frontendAppId string = frontendApp.id
output backendAppId string = backendApp.id
output functionAppId string = functionApp.id
output frontendAppFqdn string = frontendApp.properties.defaultHostName
output backendPrincipalId string = backendApp.identity.principalId
output functionPrincipalId string = functionApp.identity.principalId

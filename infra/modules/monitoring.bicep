// ============================================================
// modules/monitoring.bicep
// CAF names:
//   Log Analytics: log-sbm-{env}-cin
//   App Insights:  appi-sbm-{env}-cin-fe / -be / -evb
// ============================================================

param location string
param base string
param retentionDays int = 30
param tags object

var logAnalyticsName      = 'log-${base}'
var appInsightsFeName     = 'appi-${base}-fe'
var appInsightsBeName     = 'appi-${base}-be'
var appInsightsEvbName    = 'appi-${base}-evb'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionDays
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

resource appInsightsFe 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsFeName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: retentionDays
  }
}

resource appInsightsBe 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsBeName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: retentionDays
  }
}

resource appInsightsEvb 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsEvbName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: retentionDays
  }
}

output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output appInsightsFrontendKey string = appInsightsFe.properties.InstrumentationKey
output appInsightsFrontendConnStr string = appInsightsFe.properties.ConnectionString
output appInsightsBackendKey string = appInsightsBe.properties.InstrumentationKey
output appInsightsBackendConnStr string = appInsightsBe.properties.ConnectionString
output appInsightsFunctionKey string = appInsightsEvb.properties.InstrumentationKey
output appInsightsFunctionConnStr string = appInsightsEvb.properties.ConnectionString

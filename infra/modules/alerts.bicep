// ============================================================
// modules/alerts.bicep
// Default Azure Monitor alerts for all key services
// Emails configured in config.yml → alerts.email_receivers
// ============================================================

param base string
param tags object
param alertEmailReceivers array = []
param appServicePlanId string
param sqlServerId string = ''
param redisId string = ''
param keyVaultId string = ''
param cpuThresholdPercent int = 80
param memoryThresholdPercent int = 85
param sqlDtuThresholdPercent int = 80
param redisMemoryThresholdPercent int = 80

var actionGroupName = 'ag-${base}'

// ── Action Group — who gets notified ─────────────────────────
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'SBM-Alerts'
    enabled: true
    emailReceivers: [for receiver in alertEmailReceivers: {
      name: receiver.name
      emailAddress: receiver.email
      useCommonAlertSchema: true
    }]
  }
}

// ── Alert: CPU High ───────────────────────────────────────────
resource alertCpu 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${base}-cpu-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan CPU usage is high'
    severity: 2
    enabled: true
    scopes: [ appServicePlanId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: cpuThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Memory High ────────────────────────────────────────
resource alertMemory 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${base}-memory-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan memory usage is high'
    severity: 2
    enabled: true
    scopes: [ appServicePlanId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          threshold: memoryThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: SQL DTU High ───────────────────────────────────────
resource alertSqlDtu 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(sqlServerId)) {
  name: 'alert-${base}-sql-dtu'
  location: 'global'
  tags: tags
  properties: {
    description: 'SQL Server DTU consumption is high'
    severity: 2
    enabled: true
    scopes: [ sqlServerId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighDTU'
          metricName: 'dtu_consumption_percent'
          operator: 'GreaterThan'
          threshold: sqlDtuThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Redis Memory High ──────────────────────────────────
resource alertRedis 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(redisId)) {
  name: 'alert-${base}-redis-memory'
  location: 'global'
  tags: tags
  properties: {
    description: 'Redis Cache memory usage is high'
    severity: 2
    enabled: true
    scopes: [ redisId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighRedisMemory'
          metricName: 'usedmemorypercentage'
          operator: 'GreaterThan'
          threshold: redisMemoryThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Key Vault Availability ────────────────────────────
resource alertKv 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(keyVaultId)) {
  name: 'alert-${base}-kv-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Key Vault availability dropped'
    severity: 1
    enabled: true
    scopes: [ keyVaultId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'KvAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name

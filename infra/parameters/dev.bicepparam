// ============================================================
// parameters/dev.bicepparam
// DO NOT EDIT — all values driven from infra/config.yml
// ============================================================

using '../main.bicep'

var cfg = loadYamlContent('../config.yml')
var env = cfg.environments.dev
var prj = cfg.project
var alr = cfg.alerts

param environment            = 'dev'
param projectName            = prj.name
param location               = env.location
param regionShort            = env.region_short

// ── Feature Flags ─────────────────────────────────────────────
param deployAppGateway       = env.deploy_app_gateway
param deployApim             = env.deploy_apim
param deployNatGateway       = env.deploy_nat_gateway
param deployScheduler        = env.deploy_scheduler
param deployDdosProtection   = env.deploy_ddos_protection
param deployDr               = env.deploy_dr

// ── DR Config ─────────────────────────────────────────────────
param drSecondaryLocation    = env.dr.secondary_location
param drSecondaryRegionShort = env.dr.secondary_region_short
param drSqlFailover          = env.dr.sql_failover
param drTrafficManager       = env.dr.traffic_manager

// ── Alerts ────────────────────────────────────────────────────
param alertsEnabled               = alr.enabled
param alertEmailReceivers         = alr.email_receivers
param cpuThresholdPercent         = alr.cpu_threshold_percent
param memoryThresholdPercent      = alr.memory_threshold_percent
param sqlDtuThresholdPercent      = alr.sql_dtu_threshold_percent
param redisMemoryThresholdPercent = alr.redis_memory_threshold_percent

// ── Compute ───────────────────────────────────────────────────
param appServicePlanSku      = env.app_service.sku
param appServicePlanTier     = env.app_service.tier

// ── Database ──────────────────────────────────────────────────
param sqlAdminLogin          = env.sql.admin_login
param sqlAdminPassword       = ''
param sqlDatabaseSku         = env.sql.database_sku

// ── Redis ─────────────────────────────────────────────────────
param redisSkuName           = env.redis.sku
param redisCacheFamily       = env.redis.family
param redisCacheCapacity     = env.redis.capacity

// ── Event Hub ─────────────────────────────────────────────────
param eventHubThroughputUnits      = env.eventhub.throughput_units
param eventHubPartitionCount       = env.eventhub.partition_count
param eventHubMessageRetentionDays = env.eventhub.retention_days

// ── Storage ───────────────────────────────────────────────────
param storageAccountSku      = env.storage.sku

// ── Monitoring ────────────────────────────────────────────────
param logAnalyticsRetentionDays = env.monitoring.log_retention_days

// ── Network ───────────────────────────────────────────────────
param vnetAddressPrefix      = env.network.vnet_prefix
param appSubnetPrefix        = env.network.app_subnet
param dataSubnetPrefix       = env.network.data_subnet
param gwSubnetPrefix         = env.network.gw_subnet

// ── Key Vault ─────────────────────────────────────────────────
param kvSecretExpiryDays         = env.keyvault.secret_expiry_days
param kvSoftDeleteRetentionDays  = env.keyvault.soft_delete_retention_days
param kvAllowedIpAddresses       = []

// ── APIM ──────────────────────────────────────────────────────
param apimPublisherEmail     = prj.apim_publisher_email
param apimPublisherName      = prj.apim_publisher_name

// ============================================================
// parameters/prod.bicepparam
// DO NOT EDIT — all values are driven from infra/config.yml
// ============================================================

using '../main.bicep'

// ── Read everything from config.yml ──────────────────────────
var cfg = loadYamlContent('../config.yml')
var env = cfg.environments.prod
var prj = cfg.project

param environment            = 'prod'
param projectName            = prj.name
param location               = env.location
param regionShort            = env.region_short

// ── Feature Flags ─────────────────────────────────────────────
param deployAppGateway       = env.deploy_app_gateway
param deployApim             = env.deploy_apim
param deployNatGateway       = env.deploy_nat_gateway

// ── Compute ───────────────────────────────────────────────────
param appServicePlanSku      = env.app_service.sku
param appServicePlanTier     = env.app_service.tier

// ── Database ──────────────────────────────────────────────────
param sqlAdminLogin          = env.sql.admin_login
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

// ── APIM ──────────────────────────────────────────────────────
param apimPublisherEmail     = prj.apim_publisher_email
param apimPublisherName      = prj.apim_publisher_name

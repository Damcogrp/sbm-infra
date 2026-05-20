// ============================================================
// modules/redis.bicep — Production Standard
// CAF name: redis-sbm-{env}-cin
// SECURITY: Primary key and connection string are NOT output.
//   main.bicep constructs the connection string and stores
//   it in Key Vault.
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('Redis SKU tier: Basic, Standard, or Premium')
@allowed(['Basic', 'Standard', 'Premium'])
param redisSkuName string = 'Standard'

@description('Redis SKU family: C (Basic/Standard) or P (Premium)')
@allowed(['C', 'P'])
param redisFamily string = 'C'

@description('Redis cache capacity (0-6 for C family, 1-5 for P family)')
param redisCapacity int = 1

param tags object

var redisCacheName = 'redis-${base}'

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: redisSkuName
      family: redisFamily
      capacity: redisCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// ── Outputs (safe — no secrets) ──
output redisCacheId string = redisCache.id
output redisCacheName string = redisCache.name
output redisCacheHostName string = redisCache.properties.hostName
output redisConnectionString string = '${redisCache.properties.hostName}:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'

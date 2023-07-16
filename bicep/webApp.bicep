@description('Web app name')
@minLength(2)
param webAppName string = 'AzGovViz-${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU of App Service Plan.')
param sku string

@description('The Runtime stack of current web app')
param runtimeStack string

@description('App Service Plan name')
param appServicePlanName string = 'AppServicePlan-${webAppName}'

@description('The kind of App Service Plan.')
param kind string = 'Windows'

@description('The public network access of the web app')
param publicNetworkAccess string

@description('The tenant id of the subscription (used for AAD authentication)')
param tenantId string = subscription().tenantId

@description('The client id of the AAD application (used for AAD authentication)')
param clientId string

@description('The client secret of the AAD application (used for AAD authentication)')
@secure()
param clientSecret string

@description('The AzGovViz management group id')
param managementGroupId string

var loginEndpointUri = environment().authentication.loginEndpoint
var defaultDocument = 'AzGovViz_${managementGroupId}.html'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
  }
  kind: kind
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      publicNetworkAccess: publicNetworkAccess
      windowsFxVersion: runtimeStack
      defaultDocuments: [
        defaultDocument
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource authSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      redirectToProvider: 'azureActiveDirectory'
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: '${loginEndpointUri}/${tenantId}/v2.0'
          clientId: clientId
          clientSecretSettingName: 'AzureAdClientSecret'
        }
      }
    }
  }
}

resource webAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    AzureAdClientSecret: clientSecret
  }

}

output webAppName string = webApp.name

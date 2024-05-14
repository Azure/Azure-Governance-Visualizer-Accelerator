@description('Web app name')
@minLength(2)
param webAppName string = 'AzGovViz-${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU of App Service Plan.')
param sku string

@description('The Runtime stack of the web app')
param runtimeStack string

@description('App Service Plan name')
param appServicePlanName string = 'AppServicePlan-${webAppName}'

@description('The kind of App Service Plan.')
param kind string = 'Windows'

@description('The public network access of the web app')
param publicNetworkAccess string

@description('The Microsoft Entra tenant ID of the Azure subscription (used for user authentication)')
param tenantId string = subscription().tenantId

@description('The client ID of the Microsoft Entra application (used for user authentication)')
param clientId string

@description('The client secret of the Microsoft Entra application (used for user authentication)')
@secure()
param clientSecret string

@description('The AzGovViz management group ID')
param managementGroupId string

@description('The authorized groups IDs to access the web app')
param authorizedGroupId string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
  }
  kind: kind
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
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
        'AzGovViz_${managementGroupId}.html'
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource authSettings 'config' = {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        redirectToProvider: 'azureActiveDirectory'
        unauthenticatedClientAction: 'RedirectToLoginPage'
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            openIdIssuer: '${environment().authentication.loginEndpoint}/${tenantId}/v2.0'
            clientId: clientId
            clientSecretSettingName: 'AzureAdClientSecret'
          }
          validation: {
            jwtClaimChecks: {
              allowedGroups: [
                authorizedGroupId
              ]
            }
            defaultAuthorizationPolicy: {
              allowedPrincipals: {
                groups: [
                  authorizedGroupId
                ]
              }
            }
          }
        }
      }
    }
  }

  resource appsettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureAdClientSecret: clientSecret
      WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenantId
    }
  }

  resource webAppPublishSettings 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: true
    }
  }
}

output webAppName string = webApp.name

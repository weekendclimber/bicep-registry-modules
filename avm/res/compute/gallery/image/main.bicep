metadata name = 'Compute Galleries Image Definitions'
metadata description = 'This module deploys an Azure Compute Gallery Image Definition.'

@sys.description('Required. Name of the image definition.')
@minLength(1)
@maxLength(80)
param name string

@sys.description('Optional. Location for all resources.')
param location string = resourceGroup().location

@sys.description('Conditional. The name of the parent Azure Shared Image Gallery. Required if the template is used in a standalone deployment.')
@minLength(1)
param galleryName string

@sys.description('Required. This is the gallery image definition identifier.')
param identifier identifierType

@sys.description('Required. This property allows the user to specify the state of the OS of the image.')
param osState ('Generalized' | 'Specialized')

@sys.description('Required. This property allows you to specify the type of the OS that is included in the disk when creating a VM from a managed image.')
param osType ('Linux' | 'Windows')

@sys.description('Optional. The privacy statement uri.')
param privacyStatementUri string?

@sys.description('Optional. Describes the gallery image definition purchase plan. This is used by marketplace images.')
param purchasePlan purchasePlanType?

@sys.description('Optional. Describes the resource range (1-128 CPU cores).')
param vCPUs resourceRangeType = { min: 1, max: 4 }

@sys.description('Optional. Describes the resource range (1-4000 GB RAM).')
param memory resourceRangeType = { min: 4, max: 16 }

@sys.description('Optional. The release note uri. Has to be a valid URL.')
param releaseNoteUri string?

@sys.description('Optional. The security type of the image. Requires a hyperVGeneration V2. Note, if storing images for e.g., DevBoxes, \'TrustedLaunch\' is required.')
param securityType (
  | 'Standard'
  | 'ConfidentialVM'
  | 'TrustedLaunchSupported'
  | 'TrustedLaunch'
  | 'TrustedLaunchAndConfidentialVmSupported'
  | 'ConfidentialVMSupported')?

@sys.description('Optional. Specify if the image supports accelerated networking.')
param isAcceleratedNetworkSupported bool?

@sys.description('Optional. Specifiy if the image supports hibernation.')
param isHibernateSupported bool?

@sys.description('Optional. Must be set to true if the gallery image features are being updated.')
param allowUpdateImage bool?

@sys.description('Optional. The architecture of the image. Applicable to OS disks only.')
param architecture ('x64' | 'Arm64')?

@sys.description('Optional. The description of this gallery image definition resource. This property is updatable.')
param description string?

@sys.description('Optional. Describes the disallowed disk types.')
param disallowed disallowedType?

@sys.description('Optional. The end of life date of the gallery image definition. This property can be used for decommissioning purposes. This property is updatable.')
param endOfLifeDate string?

@sys.description('Optional. The Eula agreement for the gallery image definition.')
param eula string?

@sys.description('Optional. The hypervisor generation of the Virtual Machine. If this value is not specified, then it is determined by the securityType parameter. If the securityType parameter is specified, then the value of hyperVGeneration will be V2, else V1.')
param hyperVGeneration ('V1' | 'V2')?

@sys.description('Optional. The disk controllers that an OS disk supports.')
param diskControllerType ('SCSI' | 'SCSI, NVMe' | 'NVMe, SCSI')?

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@sys.description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]?

@sys.description('Optional. Tags for all the image.')
@metadata({
  example: '''
{
    key1: 'value1'
    key2: 'value2'
}
'''
})
param tags resourceInput<'Microsoft.Compute/galleries/images@2024-03-03'>.tags?

var builtInRoleNames = {
  'Compute Gallery Sharing Admin': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '1ef6a3be-d0ac-425d-8c01-acb62866290b'
  )
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
  )
  'User Access Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
  )
}

var formattedRoleAssignments = [
  for (roleAssignment, index) in (roleAssignments ?? []): union(roleAssignment, {
    roleDefinitionId: builtInRoleNames[?roleAssignment.roleDefinitionIdOrName] ?? (contains(
        roleAssignment.roleDefinitionIdOrName,
        '/providers/Microsoft.Authorization/roleDefinitions/'
      )
      ? roleAssignment.roleDefinitionIdOrName
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName))
  })
]

resource gallery 'Microsoft.Compute/galleries@2024-03-03' existing = {
  name: galleryName
}

resource image 'Microsoft.Compute/galleries/images@2024-03-03' = {
  name: name
  parent: gallery
  location: location
  tags: tags
  properties: {
    allowUpdateImage: allowUpdateImage != null ? allowUpdateImage : null
    architecture: architecture
    description: description
    disallowed: {
      diskTypes: disallowed.?diskTypes ?? []
    }
    endOfLifeDate: endOfLifeDate
    eula: eula
    features: union(
      (isAcceleratedNetworkSupported != null // Accelerated network is not set by default and must not be set for unsupported skus
        ? [
            {
              name: 'IsAcceleratedNetworkSupported'
              value: '${isAcceleratedNetworkSupported}'
            }
          ]
        : []),
      (securityType != null && securityType != 'Standard' // Standard is the default and is not set
        ? [
            {
              name: 'SecurityType'
              value: '${securityType}'
            }
          ]
        : []),
      (isHibernateSupported != null
        ? [
            {
              name: 'IsHibernateSupported'
              value: '${isHibernateSupported}'
            }
          ]
        : []),
      (diskControllerType != null
        ? [
            {
              name: 'DiskControllerTypes'
              value: '${diskControllerType}'
            }
          ]
        : [])
    )
    hyperVGeneration: hyperVGeneration ?? (!empty(securityType ?? '') ? 'V2' : 'V1')
    identifier: {
      publisher: identifier.publisher
      offer: identifier.offer
      sku: identifier.sku
    }
    osState: osState
    osType: osType
    privacyStatementUri: privacyStatementUri
    ...(purchasePlan != null ? { purchasePlan: purchasePlan } : {})
    recommended: { vCPUs: vCPUs, memory: memory }
    releaseNoteUri: releaseNoteUri
  }
}

resource image_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (roleAssignment, index) in (formattedRoleAssignments ?? []): {
    name: roleAssignment.?name ?? guid(image.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    properties: {
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalId: roleAssignment.principalId
      description: roleAssignment.?description
      principalType: roleAssignment.?principalType
      condition: roleAssignment.?condition
      conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
      delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
    }
    scope: image
  }
]

@sys.description('The resource group the image was deployed into.')
output resourceGroupName string = resourceGroup().name

@sys.description('The resource ID of the image.')
output resourceId string = image.id

@sys.description('The name of the image.')
output name string = image.name

@sys.description('The location the resource was deployed into.')
output location string = image.location

// =============== //
//   Definitions   //
// =============== //

@export()
@sys.description('The type for a resource range.')
type resourceRangeType = {
  @sys.description('Optional. The minimum number of the resource.')
  @minValue(1)
  min: int?

  @sys.description('Optional. The minimum number of the resource.')
  max: int?
}

@sys.description('The type for a list of disallowed disk types.')
type disallowedType = {
  @sys.description('Required. A list of disk types.')
  @metadata({ example: '''
  [
    'Standard_LRS'
  ]''' })
  diskTypes: string[]
}

@export()
@sys.description('The type for an image identifier.')
type identifierType = {
  @sys.description('Required. The name of the gallery image definition publisher.')
  publisher: string

  @sys.description('Required. The name of the gallery image definition offer.')
  offer: string

  @sys.description('Required. The name of the gallery image definition SKU.')
  sku: string
}

@export()
@sys.description('The type for an image purchase plan.')
type purchasePlanType = {
  @sys.description('Required. The plan ID.')
  name: string

  @sys.description('Required. The product ID.')
  product: string

  @sys.description('Required. The publisher ID.')
  publisher: string
}

param(
  [string] $NetworkIsolationMode,
  [string] $SubscriptionID,
  [string] $ResourceGroupName,
  [string] $ResourceGroupLocation,
  [string] $SynapseWorkspaceName,
  [string] $SynapseWorkspaceID,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $WorkspaceDataLakeAccountName,
  [string] $WorkspaceDataLakeAccountID,
  [string] $RawDataLakeAccountName,
  [string] $RawDataLakeAccountID,
  [string] $CuratedDataLakeAccountName,
  [string] $CuratedDataLakeAccountID,
  [string] $UAMIIdentityID,
  [bool] $CtrlDeployAI,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AzMLSynapseLinkedServiceIdentityID,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AzMLWorkspaceName,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $TextAnalyticsAccountID,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $TextAnalyticsAccountName,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $TextAnalyticsEndpoint,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AnomalyDetectorAccountID,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AnomalyDetectorAccountName,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AnomalyDetectorEndpoint
)


#------------------------------------------------------------------------------------------------------------
# FUNCTION DEFINITIONS
#------------------------------------------------------------------------------------------------------------
function Set-SynapseControlPlaneOperation{
  param (
    [string] $SynapseWorkspaceID,
    [string] $HttpRequestBody
  )
  
  $uri = "https://management.azure.com$SynapseWorkspaceID`?api-version=2021-06-01"
  $token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
  $headers = @{ Authorization = "Bearer $token" }

  $retrycount = 1
  $completed = $false
  $secondsDelay = 60

  while (-not $completed) {
    try {
      Invoke-RestMethod -Method Patch -ContentType "application/json" -Uri $uri -Headers $headers -Body $HttpRequestBody -ErrorAction Stop
      Write-Host "Control plane operation completed successfully."
      $completed = $true
    }
    catch {
      if ($retrycount -ge $retries) {
          Write-Host "Control plane operation failed the maximum number of $retryCount times."
          Write-Warning $Error[0]
          throw
      } else {
          Write-Host "Control plane operation failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Write-Warning $Error[0]
          Start-Sleep $secondsDelay
          $retrycount++
      }
    }
  }
}

function Save-SynapseLinkedService{
  param (
    [string] $SynapseWorkspaceName,
    [string] $LinkedServiceName,
    [string] $LinkedServiceRequestBody
  )

  [string] $uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/linkedservices/$LinkedServiceName"
  $uri += "?api-version=2019-06-01-preview"

  Write-Host "Creating Linked Service [$LinkedServiceName]..."
  $retrycount = 1
  $completed = $false
  $secondsDelay = 60

  while (-not $completed) {
    try {
      Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $LinkedServiceRequestBody -ErrorAction Stop
      Write-Host "Linked service [$LinkedServiceName] created successfully."
      $completed = $true
    }
    catch {
      if ($retrycount -ge $retries) {
          Write-Host "Linked service [$LinkedServiceName] creation failed the maximum number of $retryCount times."
          Write-Warning $Error[0]
          throw
      } else {
          Write-Host "Linked service [$LinkedServiceName] creation failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Write-Warning $Error[0]
          Start-Sleep $secondsDelay
          $retrycount++
      }
    }
  }
}

#------------------------------------------------------------------------------------------------------------
# MAIN SCRIPT BODY
#------------------------------------------------------------------------------------------------------------

$retries = 10
$secondsDelay = 60

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATION: ASSIGN SYNAPSE WORKSPACE ADMINISTRATOR TO USER-ASSIGNED MANAGED IDENTITY
# UAMI needs Synapse Admin rights before it can make calls to the Data Plane APIs to create Synapse objects
#------------------------------------------------------------------------------------------------------------

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headers = @{ Authorization = "Bearer $token" }

$uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/rbac/roleAssignments?api-version=2020-02-01-preview"

#Assign Synapse Workspace Administrator Role to UAMI
$body = "{
  roleId: ""6e4bf58a-b8e1-4cc3-bbf9-d73143322b78"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign Synapse Administrator Role to UAMI..."

Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATION: ASSIGN SYNAPSE APACHE SPARK ADMINISTRATOR TO AZURE ML LINKED SERVICE MSI
# If AI Services are deployed, then Azure ML MSI needs Synapse Spark Admin rights to use Spark clusters as compute
#------------------------------------------------------------------------------------------------------------

if (-not ([string]::IsNullOrEmpty($AzMLSynapseLinkedServiceIdentityID))) {
  #Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity
  # https://docs.microsoft.com/en-us/azure/machine-learning/how-to-link-synapse-ml-workspaces#link-workspaces-with-the-python-sdk

  $body = "{
    roleId: ""c3a6d2f1-a26f-4810-9b0f-591308d5cbf1"",
    principalId: ""$AzMLSynapseLinkedServiceIdentityID""
  }"

  Write-Host "Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity..."
  Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

  # From: https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
  # Changes made to Synapse RBAC role assignments may take 2-5 minutes to take effect.
  # Retry logic required before calling further APIs
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE AZURE KEY VAULT LINKED SERVICE
#------------------------------------------------------------------------------------------------------------

#Create AKV Linked Service. Linked Service name same as Key Vault's.

$body = "{
  name: ""$KeyVaultName"",
  properties: {
      annotations: [],
      type: ""AzureKeyVault"",
      typeProperties: {
          baseUrl: ""https://$KeyVaultName.vault.azure.net/""
      }
  }
}"

Save-SynapseLinkedService $SynapseWorkspaceName $KeyVaultName $body


#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATOR: DISABLE PUBLIC NETWORK ACCESS
# For vNet-integrated deployments, disable public network access. Access to Synapse only through private endpoints.
#------------------------------------------------------------------------------------------------------------

if ($NetworkIsolationMode -eq "vNet") {
  $body = "{properties:{publicNetworkAccess:""Disabled""}}"
  Set-SynapseControlPlaneOperation -SynapseWorkspaceID $SynapseWorkspaceID -HttpRequestBody $body
}

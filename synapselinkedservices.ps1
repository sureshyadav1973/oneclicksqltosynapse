param(

  [string] $SynapseWorkspaceName,
   [string] $KeyVaultName,
  [string] $UAMIIdentityID,
  [string] $sourceServerName,
   [string] $VMSecretName,
  [string] $IntegrationRuntimeName,
  [string] $sourceWindowsAdminUserName
  
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
# DATA PLANE OPERATION: CREATE FILESYSTEM LINKED SERVICES TO VM
#------------------------------------------------------------------------------------------------------------
$body = "{
    name: ""$sourceServerName"",
    properties: {
        parameters: 
        annotations: [],
        type: ""FileServer"",
        typeProperties: {
            host: ""c:\\\\"",
            userId: ""$sourceWindowsAdminUserName"",
            password: {
                type: ""AzureKeyVaultSecret"",
                store: {
                    referenceName: ""$KeyVaultName"",
                    type: ""LinkedServiceReference""
                },
                secretName: ""$VMSecretName""
            }
        },
        connectVia: {
            referenceName: ""$IntegrationRuntimeName"",
            type: ""IntegrationRuntimeReference""
        }
    }
} "

Save-SynapseLinkedService $SynapseWorkspaceName $sourceServerName $body

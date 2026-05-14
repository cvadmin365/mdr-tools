# --- Configuration ---
$LEAD_GROUP_ID = "7707e9e7-bfad-4abc-92a0-655d5141c2cc"
$RG            = "rg-mdr-production"
$IMAGE         = "lumonregistry.azurecr.io/mdr-terminal:prod"
$IDENTITY_NAME = "id-mdr-worker-prod"

# 1. Get current user's Entra ID context
Write-Host "Connecting to Lumon Infrastructure..." -ForegroundColor Cyan
$userObjectId = az ad signed-in-user show --query id -o tsv
$currentUser  = az ad signed-in-user show --query displayName -o tsv

Write-Host "Verifying permissions for $currentUser..." -ForegroundColor Cyan

# 2. Check Entra ID Group Membership
$isLead = az ad group member check --group $LEAD_GROUP_ID --member-id $userObjectId --query value

if ($isLead -eq "true") {
    $ROLE = "LEAD"
} else {
    $ROLE = "WORKER"
}

# 3. Retrieve Managed Identity ID
$MSI_ID = $(az identity show --resource-group $RG --name $IDENTITY_NAME --query id -o tsv)

# 4. Provision and Attach
Write-Host "Initializing Terminal (Role: $ROLE)..." -ForegroundColor Green

# Use a safer naming convention for Cloud Shell (Linux-based)
$cleanName = $currentUser.Replace(" ","").ToLower()
$containerName = "mdr-session-$cleanName"

az container create `
  --resource-group $RG `
  --name $containerName `
  --image $IMAGE `
  --os-type Linux `
  --cpu 1 --memory 1.5 `
  --vnet vnet-mdr --subnet prod `
  --restart-policy Never `
  --assign-identity $MSI_ID `
  --acr-identity $MSI_ID `
  --environment-variables LUMON_ROLE=$ROLE REFINER_NAME="$currentUser"

Write-Host "Connection established. Welcome to the terminal." -ForegroundColor Cyan
az container attach --resource-group $RG --name $containerName

# 5. Cleanup
Write-Host "Work shift ended. Decommissioning terminal..." -ForegroundColor Yellow
az container delete --resource-group $RG --name $containerName --yes

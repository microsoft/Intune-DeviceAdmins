<#
.SYNOPSIS
    Deregister autopilot device
.DESCRIPTION
    Powershell script used to deregister one device from Intune autopilot. 
    It works by connecting to Azure with your credentials, getting a graph api token using client id,
    certificate, and tenant name, and deregisters an Intune device from Autopilot using the graph api.
    Instead of using an Azure AD app and certficate, you can also use an msi for graph api permissions.
.PARAMETER TenantName
    The tenant named used to get the graph api access token
.PARAMETER ClientId
    Azure AD App client id used to get the graph api access token
.PARAMETER VaultName
    The azure key vault name that stores the certificate for client id
.PARAMETER CertificateName
    The name of the certificate in the azure key vault
.PARAMETER SerialNumber
    The serial number for the Intune device being deregistered from Intune Autopilot
.NOTES
    Version:        1.0
    Creation date:  04/25/2022
    Purpose/Change: Open Source example
#>

function Get-AccessToken
{
    param
    (
        [Parameter(Mandatory=$true)]
        [Validateset("https://graph.microsoft.com","https://vault.azure.net","https://management.azure.com","https://database.windows.net")]
        $ResourceUri,
        [Parameter(Mandatory=$true)]
        $ClientId,
        [Parameter(Mandatory=$true)]
        [Security.Cryptography.X509Certificates.X509Certificate2]
        $ClientCertificate
    )
    $PSModule = $ExecutionContext.SessionState.Module
    $PSModuleRoot = $PSModule.ModuleBase
    $IdentityClientdll = "$PSModuleRoot\Microsoft.Identity.Client.dll" #This dll is included in the folder with this script
    Add-Type -LiteralPath $IdentityClientdll
    [string[]] $Scopes = "$ResourceUri/.default"
    $TenantName = "" #Enter your tenant name
    $Authority = "https://login.windows.net/$($TenantName)"
    $ClientApplication  = [Microsoft.Identity.Client.ConfidentialClientApplicationBuilder]::Create($ClientId).WithCertificate($ClientCertificate,$true).WithAuthority($Authority).Build()
    $AquireTokenParameters = $ClientApplication.AcquireTokenForClient($Scopes)
    $TokenResponse = $AquireTokenParameters.ExecuteAsync().GetAwaiter().GetResult()
    return $TokenResponse.AccessToken
}

function Delete-Device
{
    param
    (
        [Parameter(Mandatory=$true)]
        $SerialNumber
    )
    try 
    {
        Write-Output "------------------- Starting AutoPilot device deletion script -------------------"
        $ClientId = "" #Enter your client id for getting access token
        #Client id must have graph api permission: DeviceManagementServiceConfig.ReadWrite.All

        $VaultName = "" #Enter your key vault name for getting client certificate
        $CertificateName = "" #Enter your key vault certificate name for client certificate
        Write-Output "Logging into Azure"
        Login-AzAccount
        Write-Output "Getting client certificate using clientid: $ClientId"
        $ClientCertificate = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertificateName
        Write-Output "Getting microsoft graph api access token using client certificate"
        $GraphApiToken  = Get-AccessToken -ResourceUri "https://graph.microsoft.com" -ClientId $ClientId -ClientCertificate $ClientCertificate
        $Headers = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer " + $GraphApiToken
        }
        $EncodedSerialNumber = [uri]::EscapeDataString($SerialNumber)
        $AutoPilotDeviceUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$EncodedSerialNumber')"
        Write-Output "Getting Device using URL: $($AutoPilotDeviceUrl)"
        $APDevice = Invoke-RestMethod -Method Get -Uri $AutoPilotDeviceUrl -Headers $Headers
        if($APDevice.value.ID)
        {
            $AutoPilotDeviceDeleteUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($APDevice.Value.Id)"
            Write-Output "Attempting to delete device serial number: $SerialNumber"            
            Invoke-RestMethod -Method DELETE -Uri $AutoPilotDeviceDeleteUrl -Headers $Headers
            Write-Output "AutoPilot device deleted with serial number: $SerialNumber"
        }
        else
        {
            Write-Output "AutoPilot device with serial number: $SerialNumber not found"
        }
    }
    catch 
    {
        Write-Output "Error while deleting device with serial number: $SerialNumber"
        Write-Error $_.Exception.Message
    }
}

$SerialNumber = "" #Enter your device serial id to delete
Delete-Device -SerialNumber $SerialNumber #Make sure to run Powershell ISE as Admin before running the script
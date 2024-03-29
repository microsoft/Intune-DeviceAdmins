﻿<#
.SYNOPSIS
    Deregister Autopilot Device
.DESCRIPTION
    Powershell script used to deregister one device from Intune Autopilot. 
    It works by connecting to Azure with your credentials, getting a Graph API token using Client Id,
    Certificate, and Tenant Name, and deregisters an Intune device from Autopilot using the Graph API.
    Instead of using an Azure AD App and certficate, you can also use an MSI for Graph API permissions.
.PARAMETER TenantName
    The Tenant Name used to get the Graph API access token
.PARAMETER ClientId
    Azure AD App Client Id used to get the Graph API access token
.PARAMETER VaultName
    The Azure Key Vault name that stores the certificate for Client Id
.PARAMETER CertificateName
    The name of the certificate in the Azure Key Vault
.PARAMETER SerialNumber
    The Serial Number for the Intune device being deregistered from Intune Autopilot
.PARAMETER IdentityClientdll
    Path to the Microsoft.Identity.Client dll
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
    $IdentityClientdll = "" #Path to the Microsoft.Identity.Client dll
    #Run the Powershell command: Install-Module -Name Microsoft.Identity.Client
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
        $ClientId = "" #Enter your Client Id for getting access token
        #Client Id must have Graph API permission: DeviceManagementServiceConfig.ReadWrite.All

        $VaultName = "" #Enter your Key Vault name for getting client certificate
        $CertificateName = "" #Enter your Key Vault certificate name for client certificate
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

$SerialNumber = "" #Enter your Device Serial Number to delete
Delete-Device -SerialNumber $SerialNumber #Make sure to run Powershell ISE as Admin before running the script
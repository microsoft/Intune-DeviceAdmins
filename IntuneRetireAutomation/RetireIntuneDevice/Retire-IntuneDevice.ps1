<#
.SYNOPSIS
    Retire Intune Device
.DESCRIPTION
    Powershell script used to retire one device from Intune. 
    It works by connecting to Azure with your credentials, getting a Graph API token using Client Id,
    certificate, and Tenant Name, and retires an Intune device using the Graph API.
    Instead of using an Azure AD App and certficate, you can also use an MSI for Graph API permissions.
.PARAMETER TenantName
    The Tenant Name used to get the Graph API access token
.PARAMETER ClientId
    Azure AD App Client Id used to get the Graph API access token
.PARAMETER VaultName
    The Azure Key Vault name that stores the certificate for Client Id
.PARAMETER CertificateName
    The name of the certificate in the Azure Key Vault
.PARAMETER IntuneDeviceID
    The Intune Device Id for the Intune device being retired
.PARAMETER IdentityClientdll
    Path to the Microsoft.Identity.Client dll
.NOTES
    Version:        1.0
    Creation date:  1/9/2023
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
    $TenantName = "" #Enter your Tenant Name
    $Authority = "https://login.windows.net/$($TenantName)"
    $ClientApplication  = [Microsoft.Identity.Client.ConfidentialClientApplicationBuilder]::Create($ClientId).WithCertificate($ClientCertificate,$true).WithAuthority($Authority).Build()
    $AquireTokenParameters = $ClientApplication.AcquireTokenForClient($Scopes)
    $TokenResponse = $AquireTokenParameters.ExecuteAsync().GetAwaiter().GetResult()
    return $TokenResponse.AccessToken
}

function Retire-Device  
{
    param
    (
        [Parameter(Mandatory=$true)]
        $IntuneDeviceID
    )
    try 
    {
        Write-Output "------------------- Starting Retire Intune Device Script -------------------"
        $ClientId = "" #Enter your Client Id for getting access token
        #Client Id must have Graph API permission: DeviceManagementManagedDevices.PrivilegedOperations.All

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
        $IntuneDeviceUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($IntuneDeviceID)"
        Write-Output "Getting Device using URL: $($IntuneDeviceUrl)"
        $IntuneDevice = Invoke-RestMethod -Method Get -Uri $IntuneDeviceUrl -Headers $Headers
        if($IntuneDevice)
        {
            Write-Output "Attempting to retire Intune Device Id: $IntuneDeviceID"          
            $IntuneRetireUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($IntuneDevice.Id)/retire"
            Invoke-RestMethod -Method POST -Uri $IntuneRetireUrl -Headers $Headers
            Write-Output "Intune device retired"
        }
        else
        {
            Write-Output "Intune Device with device id: $IntuneDeviceID not found"
        }
    }
    catch 
    {
        Write-Output "Error while retiring device with id: $IntuneDeviceID"
        Write-Error $_.Exception.Message
    }
}

$IntuneDeviceID = "" #Enter your Intune Device ID to retire
Retire-Device -IntuneDeviceID $IntuneDeviceID 
# Autopilot Device Deregister

Powershell script used to deregister one device from Intune Autopilot. It works by connecting to Azure with your credentials, getting a Graph API token using Client Id, certificate, and Tenant Name, and deregisters an Intune device from Autopilot using the Graph API.

## Prerequisites

- Client should have Graph API permission: **DeviceManagementServiceConfig.ReadWrite.All**
- Powershell ISE
- Microsoft.Identity.Client dll

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Deregister-AutopilotDevice.ps1
2. Run the command: Install-Module -Name Microsoft.Identity.Client
3. Manually configure the following variables for your own environment:
   - TenantName: The Tenant Name used to get the Graph API access token
   - ClientId: Azure AD App Client Id used to get the Graph API access token
   - VaultName: The Azure Key Vault name that stores the certificate for Client Id
   - CertificateName: The name of the certificate in the Azure Key Vault
   - SerialNumber: The Serial Number for the Intune device being deregistered from Intune Autopilot
   - IdentityClientdll: Path to the Microsoft.Identity.Client dll
4. Run the Powershell script

## Notes

The Autopilot Device Deregister was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft. Instead of using an Azure AD App and certficate, you can also use an MSI for Graph API permissions.

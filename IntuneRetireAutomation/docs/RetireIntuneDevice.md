# Retire Intune Device

Powershell script used to retire one device from Intune. It works by connecting to Azure with your credentials, getting a Graph API token using Client Id, certificate, and Tenant Name, and retires an Intune device using the Graph API.

## Prerequisites

- Client should have Graph API permission: **DeviceManagementManagedDevices.PrivilegedOperations.All**
- Powershell ISE
- Microsoft.Identity.Client dll

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Retire-IntuneDevice.ps1
2. Run the command: Install-Module -Name Microsoft.Identity.Client
3. Manually configure the following variables for your own environment:
   - TenantName: The Tenant Name used to get the Graph API access token
   - ClientId: Azure AD App Client Id used to get the Graph API access token
   - VaultName: The Azure Key Vault name that stores the certificate for Client Id
   - CertificateName: The name of the certificate in the Azure Key Vault
   - IntuneDeviceID: The Intune Device ID being retired from Intune
   - IdentityClientdll: Path to the Microsoft.Identity.Client dll
4. Run the Powershell script

## Notes

The Retire Intune Device was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft. Instead of using an Azure AD App and certficate, you can also use an MSI for Graph API permissions.

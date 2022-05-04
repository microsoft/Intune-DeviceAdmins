# Autopilot Device Deregister

Powershell script used to deregister one device from Intune autopilot. It works by connecting to Azure with your credentials, getting a graph api token using client id, certificate, and tenant name, and deregisters an Intune device from Autopilot using the graph api.

## Prerequisites

- Client should have Graph api permission: **DeviceManagementServiceConfig.ReadWrite.All**
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Deregister-AutopilotDevice.ps1
2. Manually configure the following variables for your own environment:
   - TenantName: The tenant named used to get the graph api access token
   - ClientId: Azure AD App client id used to get the graph api access token
   - VaultName: The azure key vault name that stores the certificate for client id
   - CertificateName: The name of the certificate in the azure key vault
   - SerialNumber: The serial number for the Intune device being deregistered from Intune Autopilot
3. Run the Powershell script

## Notes

The Autopilot Device Deregister was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft. Instead of using an Azure AD app and certficate, you can also use an msi for graph api permissions.

# SCCM Collect Device Logs Automation

Powershell script used to collect device logs from user devices from SCCM. It works by connecting to SCCM, running a Powershell script called Collect Logs to Cloud stored in SCCM on each device collecting specific logs, connecting to an Azure Storage Account with an MSI using Client Id, and then sending the logs to the Storage Account. An HTML Report is also generated in the local filepath with the results.

## Prerequisites

- SCCM script "Collect Logs to Cloud" must be uploaded to SCCM
- Az Powershell module installed
- Azure Storage Account set up with MSI Access
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Collect-DeviceLogs.ps1
2. Manually configure the following variables for your own environment:
   - SiteCode: SCCM Site Code
   - SiteServer: SCCM Site Server
   - StorageAccountName: Name of Azure Storage Account
   - StorageAccountResourceGroup: Name of Azure Storage Account Resource Group
   - Container: Name of Container in Azure Storage Account
   - ClientId: Azure MSI Client Id used to get the Storage Account Access Token
3. Run the Powershell script

## Notes

The SCCM Collect Device Logs Automation script was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other SCCM environments outside of Microsoft.

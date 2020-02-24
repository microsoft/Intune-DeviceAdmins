
# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# QC Automation

PowerShell based quality control automation used to do pre- and post- evaluation of Configuration Manager environments.

## QC Framework utilizing Pester 

* [Pester](https://github.com/pester/Pester/wiki/Pester)

QC module resides under QC root folder and contains all functions that have business logic to write Pester test cases upon. 
* \QCAutomation\Module\QCModule.psd1 
* \QCAutomation\Module\QCModule.psm1 

There will be a separate folder for each area (e.g.\QC\Infra\Upgrade). Under Infra, we have Upgrade section. This means the QC is written for Infra client Upgrade scenarios. 

The folder will usually contain the following files:
* Config (This is input to test cases. It contains input parameters, expected values to determine whether to pass or fail the case.)
* Perform-InfraUpgradeQC (This loads both test cases and configurations, loads QC and Pester module, executes test cases uses QC module to generate and email QC report.)
* QCCheck-InfraUpgrade (all the Pester test cases.)

## Infra - Upgrade QC automation
### Steps
1) Log on to server hosting the QC automation scripts (usually Central Administration Site for Infra QC)

2) Open PowerShell console or ISE in elevated mode and execute following script: PS > C:\QC\Infra\Upgrade\Perform-InfraUpgradeQC.ps1

If you get the following error, ignore it: 

	'''Import-Module : The RPC server is unavailable. (Exception from HRESULT: 0x800706BA)
    At I:\QC\Module\QCModule.psm1:30 char:13
    +             Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\Configuration ... 
    +             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    + CategoryInfo          : OpenError: (CAZ:PSDriveInfo) [Import-Module], SmsConnectionException 
    + FullyQualifiedErrorId : Drive,Microsoft.PowerShell.Commands.ImportModuleCommand'''

3) A UI page should launch allowing you to enter various details about this particular QC test run.

Please read the instructions carefully and provide inputs accordingly. Import inputs are: 
    * QC Title  
    * Expected Client Version - this should be new version of CM client.  
    * Upgrade Schedule date and time - if you mention the values in past, it will be Post QC check or else it will be Pre-QC check 
    * Site codes - select all site codes to perform QC on. The QC will be performed one-by-one. 

4) Click on Start QC button. 

This will perform all QC checks and display verbose output. Ignore any errors you see while the script is executing. It will take around 3 minutes, however it is recommended to wait until 10 minutes to get QC completed. 

5) Once QC is complete, a report is generated under C:\QC\Infra\Upgrade\Reports folder. A new folder will be created for each execution and it will contain three files: 
    * QC results - CSV file  
    * QC results  - Html file 
    * QC results - png file (pie chart) 

6) Repeat the above steps for other sites as required

### How to analyze QC report 
The report will have graphical display of number of checks performed, passed, failed and not tested.
    * Passed - indicates these QC checks were passed 
    * Failed - indicates these QC checks were failed 
    * Not tested/Skipped/Manual - indicates these QC checks were not performed by automation. This means:
        * Either they're not possible to automate (e.g. "Verify access to CM12 Console locally") 
        * They're not yet automated. 

Passed scenarios will be self-explanatory and for "Failed" cases a FailureReason will be given. 
    * For example: 
        * '''Verify if file 'I:\Program Files\Microsoft Configuration Manager\Logs\sitestat.log' does not contain any 'Error'.'''
        * '''Expected: {} But was:  {omGetServerRoleAvailabilityState could not read from the registry on <MACHINE_NAME>; error = 5:   $$<SMS_SITE_SYSTEM_STATUS_SUMMARIZER><07-30-2018 00:00:00.620+420><thread=40800 (0x9F60)>}'''
    * This result indicates that the file was not supposed to contain any "Error", but an error line was found. 

## Client Health QC Automation
### Steps
1) Log on to Client machine where you are test. Ex: Navigate to "C:\QC\Client&Health\ClientHealth\Upgrade" 

2) Open "ClientHealthQCConfigurations.psd1" file 

3) Change the following configuration values: 

    '''InputParams = @{                    
            SiteCode = "CAS" ## [NOTE] - Change this code as per site you're performing QC On 
            UpgradeDateTime = '7/12/2018 10:00:00 AM' ## Time (PST) when upgrade is scheduled (Pre-QC) or happened (Post QC)  
        }'''
        
    '''ExpectedValues = @{ 
            ExpectedClientVersion = "5.00.8690.1000" ## Change this as per upgrade release 
            ExpectedUpgradeName = "Configuration Manager 1806" ## Change this as per upgrade release
        }'''

4) Open PowerShell console or ISE in elevated mode and execute following script: PS > C:\QC\ClientHealth\Upgrade\Perform-ClientHealthUpgradeQC.ps1 

This will perform all QC checks and display verbose output. Ignore any errors you see while the script is executing. It will take around 15 minutes, however it is recommended to wait until 30 minutes to get QC completed. 

5) Once QC is complete, a report is generated under C:\QC\ClientHealth\Upgrade\Reports folder. A new folder will be created for each execution and it will contain three files: 
    * QC results - CSV file  
    * QC results  - Html file 
    * QC results - png file (pie chart) 

### How to analyze QC report 
The report will have graphical display of number of checks performed, passed, failed and not tested. 
    * Passed - indicates these QC checks were passed
    * Failed - indicates these QC checks were failed
    * Not tested - indicates these QC checks were not performed by automation.

Passed scenarios will be self-explanatory and for "Failed" cases a FailureReason will be given.


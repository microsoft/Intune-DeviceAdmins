@{

AppsParams = @{                   
                                       
                    
                    DistributionPointGroupName = "DPG1"
                    DistributionPointName = "PPEDP01.PPE.COM" 
                    
                    DeployCollectionName = "App/Package Deployments"
                    UserCollectionName = "TCS- Internal"
                    
                    ComputerName1 = "APPOSDTESTVM01"
                    ComputerName2 = "APPOSDTESTVM02"
                    
                    #LimitingCollectionName = "PPE QC Limiting Collection"
                    IncludeCollectionName = "Include collection for Automation"
                    
                    CollectionFolderName = "QCCollectionAutomation"
                    PackageFolderName = "QCPKGAutomation"
                    ApplicationFolderName = "QCAppAutomation"

                    CollectionFolderPath = 'CAS:\DeviceCollection'
                    ApplicationFolderPath = 'CAS:\Application'
                    PackageFolderPath = 'CAS:\Package'

                    SourcePath = '\\PPEDP01\PackageSource\Edge'
                    AppSourcePath = '\\PPEDP01\PackageSource\ContosoApps\App1.msi'
                    AppxAppSourcePath = '\\PPEDP01\PackageSource\ContosoApps\Appx1.appx'
                    DependencySource = '\\PPEDP01\PackageSource\ContosoApps\App2.msi'
                    SupersedSource = '\\PPEDP01\PackageSource\ContosoApps\Appx2.appx'
                    SupersedAppSource = '\\PPEDP01\PackageSource\ContosoApps\App3.msi'
                                  
                    GlobalConditionName = 'TestCondition-Reg'
                    GlobalCondFileName = 'TestCondition-File'
                    GlobalCondWqlName = 'TestCondition-Wql'

                    ConfigurationItemName = 'QC_ConfigurationItem'
                    BaselineName = 'EDP Baseline'
                    DPMachineNameSubstring = 'DP'
                }          


SiteServers = @{
                        CAS = 'CAZ.CONTOSO.COM'                        
                }

CentralSiteDetails = @{PPE = @{SiteCode='CAS'; SiteServer='CAS.PPE.COM'; SiteSQLServer='CAS.PPE.COM'};
                       Prod = @{SiteCode='CAZ'; SiteServer='CAZ.CONTOSO.COM'; SiteSQLServer='CAZ.CONTOSO.COM'};
                      }

PrimarySiteCode = "CAS"

QCEnvironment = "PPE"

}
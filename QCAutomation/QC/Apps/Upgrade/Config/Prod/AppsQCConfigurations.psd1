@{

AppsParams = @{                                      
                    
                    DistributionPointGroupName = "DP group for deploying Packages/applications in testing"
                    DistributionPointName = "DP01.CONTOSO.COM" 
                    
                    DeployCollectionName = "App/Package Deployments"
                    
                    ComputerName1 = "APPOSDTESTVM01"
                    ComputerName2 = "APPOSDTESTVM02"
                    
                    LimitingCollectionName = "Prod QC Limiting Collection"
                    IncludeCollectionName = "Include collection for Automation"
                    
                    CollectionFolderName = "QCCollectionAutomation"
                    PackageFolderName = "QCPKGAutomation"
                    ApplicationFolderName = "QCAppAutomation"

                    CollectionFolderPath = 'CAZ:\DeviceCollection'
                    ApplicationFolderPath = 'CAZ:\Application'
                    PackageFolderPath = 'CAZ:\Package'

                    SourcePath = '\\pkgstore01\PackageSource\Edge'
                    AppSourcePath = '\\pkgstore01\PackageSource\ContosoApps\App1.msi'
                    }
          


    SiteServers = @{
        CAZ = 'CAS.CONTOSO.COM'  
        }

    CentralSiteDetails = @{PPE = @{SiteCode='CAS'; SiteServer='CAS.PPE.COM'; SiteSQLServer='CAS.PPE.COM'};
                       Prod = @{SiteCode='CAZ'; SiteServer='CAZ.CONTOSO.COM'; SiteSQLServer='CAZ.CONTOSO.COM'};
                      }


    PrimarySiteCode = "CAZ"

    QCEnvironment = "Prod"
}
@{

InputParams = @{                   
                    UpgradeDateTime = '2018-09-25 05:04' ## Time (PST) when upgrade is scheduled (Pre-QC) or happened (Post QC) 
                    SiteCode = "CAZ" ## [NOTE] - Change this code as per site you're performing QC On    
                    AppName = 'QCAppTest_01:06'
                    AvailableApp = 'MSX Apportal'
                    InstalledApp = 'QCAppTest_14:59'
                    ModerApxApp = 'QCAppxAppTest_02:33'
                    ModerDeeplinkApp = 'QCDeeplinkAppTest_02:44' 
                    SupersedesApp = 'QCAppxSupersedingApp'        
                                     
                }
ExpectedValues = @{
                    ExpectedClientVersion = "5.00.8692.1008" ## Change this as per upgrade release
                    ExpectedUpgradeName = "Test QC for Persistent admin entitlements remove on AU1 Site" ## Change this as per upgrade release
                    
                    }      


SiteServers = @{
                        CAZ = 'CAZ.CONTOSO.COM'
                        
                }

SiteSQLServers = @{
                        CAZ = 'CAZ.CONTOSO.COM'
                        
                    }

SiteSQLDBNames = @{
                        CAZ = 'CM_CAZ'
                        
                    }


PrimarySiteCode = "CAZ"

}
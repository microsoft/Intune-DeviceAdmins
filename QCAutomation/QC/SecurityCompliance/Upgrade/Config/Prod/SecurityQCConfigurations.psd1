@{

ConfigParams = @{                                                          
                    
                   DPGroupName = "DPG1"
                   CollectionName = "App/Package Deployments"
                   ArticleId = '123456'
                   SugName = "SUGManualbyQC"
                   ADRName = "SDADR_AutomationQC"
                   DeployPackageLocation = "\\CAZ\Test_SC\SCQC_Automation\"
                   Languages = "Chinese (Simplified, PRC)","Chinese (Traditional, Hong Kong S.A.R.)","Chinese (Traditional, Taiwan)","English","French","German","Italian","Japanese","Korean","Russian","Spanish"
                   QCEnvironment = "Prod"                  

                }


CentralSiteDetails = @{PPE = @{SiteCode='CAS'; SiteServer='CAS.PPE.COM'; SiteSQLServer='CAS.PPE.COM'; SUPMachineNameSubstring='SUP'; DPMachineNameSubstring='DP'};
                       Prod = @{SiteCode='CAZ'; SiteServer='CAZ.CONTOSO.COM'; SiteSQLServer='CAZ.CONTOSO.COM'; SUPMachineNameSubstring='SUP'; DPMachineNameSubstring='DP'};
                      }

}
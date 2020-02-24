@{

ConfigParams = @{                 
                    
                   DPGroupName = "DPG1" 
                   CollectionName = "App/Package Deployments"
                   ArticleId = '123456'
                   SugName = "SUGManualbyQC"
                   ADRName = "SDADR_AutomationQC"
                   DeployPackageLocation = "\\PPECAS\Test_SC\SCQC_Automation\0a20e1e5-243d-406a-81ac-3bc3a7b97237"
                   Languages = "Chinese (Simplified, PRC)","Chinese (Traditional, Hong Kong S.A.R.)","Chinese (Traditional, Taiwan)","English","French","German","Italian","Japanese","Korean","Russian","Spanish"
                   QCEnvironment = "Prod"

                }

CentralSiteDetails = @{PPE = @{SiteCode='CAS'; SiteServer='CAS.PPE.COM'; SiteSQLServer='CAS.PPE.COM'};
                       Prod = @{SiteCode='CAZ'; SiteServer='CAZ.CONTOSO.COM'; SiteSQLServer='CAZ.CONTOSO.COM'};
                      }

}
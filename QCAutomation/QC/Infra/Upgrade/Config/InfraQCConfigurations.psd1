@{

ExpectedValues = @{
                    ExpectedServiceStatus = @(
                                                @{ServiceName='CcmExec';ExpectedStatus='Running'},
                                                @{ServiceName='SMS_EXECUTIVE';ExpectedStatus='Running'}
                                                @{ServiceName='SMS_SITE_BACKUP';ExpectedStatus='Stopped'}
                                                @{ServiceName='SMS_SITE_COMPONENT_MANAGER';ExpectedStatus='Running'}
                                                @{ServiceName='SMS_SITE_VSS_WRITER';ExpectedStatus='Running';}
                                                @{ServiceName='IISADMIN';ExpectedStatus='Running'}
                                                @{ServiceName='W3SVC';ExpectedStatus='Running'}
                                             )
                    ExpectedErrorLogPattern = @{Filter="Error"; IgnoreFilter="Registry error|DeploymentError|Registryerror"}
                    ExpectedErrorLogFiles = @(
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\HMAN.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\replmgr.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\objreplmgr.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\sitecomp.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\sitestat.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\sitectrl.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\rcmctrl.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\ruleengine.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\wsyncmgr.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\WCM.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\dmpdownloader.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\dmpuploader.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\inboxmon.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\outboxmon.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\pkgxfermgr.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\statesys.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\cloudusersync.log',
                                                'C:\Program Files\Microsoft Configuration Manager\Logs\CloudMgr.log'
                                               )
                    ExpectedCrashDumpValues = @{ExpectedRootFolder='C:\Program Files\Microsoft Configuration Manager\Logs\CrashDumps'; Filter="*smsexec*"}
                    ExpectedComponentStatusMessageInputs = @{SeverityLevels=@("Error","Warning");DaysOld=7;IgnoreComponents=$null;ExpectedMinimumMessageCountPerComponent=10}
                    ExpectedInboxBoxAndOutBoxLogCheckParams = @{
                                        OutboxMon =  @{
                                                        FileName = "C:\Program Files\Microsoft Configuration Manager\Logs\outboxmon.log"
                                                        Patterns = @(
                                                                        "(\\outboxes\\statemsg.box?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\outboxes\\stat.box is?) (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>"
                                                                    )
                                                        ExpectedValue = 0
                                                     }
                                        InboxMon = @{
                                                        FileName = "C:\Program Files\Microsoft Configuration Manager\Logs\inboxmon.log"
                                                        Patterns = @(
                                                                        "(\\inboxes\\auth\\statesys.box\\incoming?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\auth\\statesys.box\\incoming\\high?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\auth\\statesys.box\\incoming\\low?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\auth\\ddm.box?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\ddm.box is?) (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\auth\\ddm.box\\userddrsonly?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>",
                                                                        "(\\inboxes\\auth\\ddm.box\\regreq?) is (\d+?)\..*\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}\+\d{3}?)\>"
                                                                    )
                                                        ExpectedValue = 0
                                                     }
                                    }
                    ExpectedBadMIFFileParams = @{FolderName = "C:\Program Files\Microsoft Configuration Manager\inboxes\auth\dataldr.box\bad"; ExpectedFileCount = 0}
                    ExpectedSMSObjectsParams = @{RootFolders = @{PPE=@("C:\SCCMContlib\Datalib\");Prod=@("I:\SCCMContlib\Datalib\")}}
                    ExpectedSQLErrorLogsParams = @{IgnorePattern = "no user action is required"; ErrorThreshold = 0}
                    ExpectedEventLogParams = @{LogNames = @('Application','Setup','System','Security'); EntryType = "Error"; IgnorePattern=$null}
                    ExpectedSUPComponentStatusMessageInputs = @{SeverityLevels=@("Error","Warning");DaysOld=7;IgnoreComponents=$null;ExpectedMinimumMessageCountPerComponent=1}
                    ExpectedSQLJobStatus = @{
                                                JobNames = @(
                                                                'ECM_DatabaseBackups',
				                                                'ECM_DBCCAll',
				                                                'ECM_BlockingSpids_Cleanup',
				                                                'ECM_DailyStatsUpdate',
				                                                'ECM_Syscommittab_PSCleanup',
				                                                'ECM_BackupChecker',
				                                                'ECM_WeeklyIndexOptimize',
				                                                'ECM_DatabaseLogBackups',
				                                                'ECM_BlockingSpids',
                                                                'ECM_CycleErrorLog'
                                                            )
                                                ExpectedEnabledStatus = 'Yes'
                                            }
                    ExpectedMPApplicationPools = @('CCM Client Notification Proxy Pool','CCM Security Token Service Pool','CCM Server Framework Pool','CCM Client Deployment Pool','CCM User Service Pool','CCM Windows Auth Server Framework Pool','CCM Windows Auth User Service Pool','DefaultAppPool','SMS Management Point Pool','SMS Windows Auth Management Point Pool')
                  }

CentralSiteDetails = @{PPE = @{SiteCode='CAS'; SiteServer='CAS.PPE.COM'; SiteSQLServer='CAS.PPE.COM'; SUPMachineNameSubstring='SUP'};
                       Prod = @{SiteCode='CAZ'; SiteServer='CAZ.CONTOSO.COM'; SiteSQLServer='CAZ.CONTOSO.COM'; SUPMachineNameSubstring='SUP'};
                      }

QCEnvironment = "Prod"

CollectionFolderPath = "CAZ:\DeviceCollection"

}
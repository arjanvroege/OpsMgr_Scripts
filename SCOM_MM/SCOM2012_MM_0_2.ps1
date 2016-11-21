#======================================================================================================================# 
#                                                                                                                      #
#                                                                                                                      # 
# SCOM2012_MM_0_2.ps1                                                                                                  # 
# Powershell Script to put a Host or Group into maintenance mode. Tested with SCOM 2012 and SCOM 2012 SP1        	   #																	   #
# Created by: Arjan Vroege																							   #
# Version: 0.2                                                                                                         #
#                                                                                                                      # 
# Usage: .\SCOM2012_MM_0_2.ps1 -Minutes <<Duration>> -Comment "<<Comment>>" -Type <<Group or Agent>> -Name	<< Name >> #
#                                                                                                                      #
# -Minutes: 	Number of Minutes                                                                                      #
# -Comment: 	Maintenance Mode comment                                                                               #
# -Type: 		Agent or SCOM Group                                                                                    #
# -Name: 		Name of the Group or Display Name of Agent                                                             #
#                                                                                                                      #
#                                                                                                                      #
#======================================================================================================================#

Param(
  [int32]$minutes,
  [string]$comment,
  [string]$type,
  [string]$name
)

#Import the Operations Manager Powershell Module
Import-Module OperationsManager

#Defining Variables
$MgntSrv   = "<< Your SCOM Management Server >>"
$startTime = (Get-Date).ToUniversalTime() 
$endTime   = $startTime.AddMinutes($Minutes)
$reason    = "PlannedOther";

if($type -eq "Group") {
    #Getting Group Objects
    $group = Get-SCOMGroup -ComputerName $MgntSrv -DisplayName $name
    
	#Check if Group is already in Maintenance Mode
    If($group.InMaintenanceMode -eq $false) {
        Write-Host "Putting Group $Name into maintenance mode." -ForeGroundColor Blue 
		$group.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive")
    }
} elseif($type -eq "Agent") {
    #Gets the SCOM Agent
    $SCOMAgent = Get-SCOMAgent -ComputerName $MgntSrv -Name $name
    $Instance  = $scomagent.HostComputer
    
    if(($clusters = $SCOMagent.GetRemotelyManagedComputers())) { 
      $clusterNodeClass = Get-SCOMClass -ComputerName $MgntSrv -Name Microsoft.Windows.Cluster.Node 
      foreach($cluster in $clusters) {
         $ClusterAgentName = $cluster.ComputerName
         $SCOMClass        = Get-SCOMClass -ComputerName $MgntSrv -Name Microsoft.Windows.Cluster
         $ClusterInstance  = Get-SCOMClassinstance -ComputerName $MgntSrv -Class $SCOMClass | where {$_.Displayname -like “*$ClusterAgentName*”} 
         if($ClusterInstance) {     
          $ClusterInstance.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive") 
          $nodes = $ClusterInstance.GetRelatedMonitoringObjects($clusterNodeClass) 
          if($nodes) { 
            foreach($node in $nodes) { 
              Write-Host "Putting $node into maintenance mode." -ForeGroundColor Green 
            } 
           } 
         }
        Write-Host "Putting $($cluster.Computer) into maintenance mode." -ForeGroundColor Blue 
        $ClusterComputer = $cluster.Computer
        $ClusterComputer.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive") 
      } 
    } else { 
      #Setting maintenance mode for computer object and/or cluster components 
      Write-Host "Putting $Instance into maintenance mode." -ForeGroundColor Blue 
      $Instance.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive")
    }
} else {
    Write-host "Exiting" -ForeGroundColor Red 
}

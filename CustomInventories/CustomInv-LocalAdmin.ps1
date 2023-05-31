<#
.SYNOPSIS
  Create Inventory for user or group in Local Administrator group
.DESCRIPTION
  Create Inventory for user or group in Local Administrator group, connecting to Active Directory to retrieving User Information if the account is an AD Account or group
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  26/02/2023
  Purpose/Change: Initial script development
.LINK
    Author : Letalys (https://github.com/Letalys)
#>

Function Invoke-CCMHardwareInventory{
    Begin{
      Write-Output "Trying to perform CCM hardware inventory..."
    }
    Process{
      Try{
        $GetSMSClient = Get-CimInstance -Class "SMS_Client" -Namespace 'root\ccm' -ErrorAction SilentlyContinue
        if($null -ne $GetSMSClient){
            Write-Output "CCM Agent found, performing hardware inventory."

	        $SMSClient = [wmiclass] "\\$($env:COMPUTERNAME)\root\ccm:SMS_Client"
	        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
        }else{
            Write-Warning "CCM Agent not found, will not perform hardware inventory."
        }
      }Catch{
        Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
        Break
      }
    }
    End{
      If($?){
        Write-Output "Completed Successfully."
      }
    }
}
Function New-WMIClass{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName,
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][Object]$ClassTemplate
	)
    
    Begin{}
    Process{
        #Check existing WMI Class
        if($null -ne (Get-WmiObject $ClassName -ErrorAction SilentlyContinue)){Write-Output "Deleting class $ClassName" ; Remove-WmiObject $ClassName}
        Write-Output "Create New WMI Class :  $ClassName"

        $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null);
	    $newClass["__CLASS"] = $ClassName;
        $newClass.Qualifiers.Add("Static", $true)

        $newClass.Properties.Add("Key", [System.Management.CimType]::String, $false)
        $newClass.Properties["Key"].Qualifiers.Add("Key", $true)

        $TemplateProperties = $ClassTemplate | Get-Member -MemberType NoteProperty

        foreach($prop in $TemplateProperties){
            Write-Output "`t Add Class Property : $($Prop.Name)"
            $newClass.Properties.Add("$($Prop.Name)", [System.Management.CimType]::String, $false)
        }
            
        $newClass.Put() | Out-Null
    }
    End{}
}
Function Add-WMIInstances {
    [CmdletBinding()]
	param
	(
        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName,
        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][System.Collections.Arraylist]$ObjectArrayList
	)
    Begin{}
    Process{
        foreach($o in $ObjectArrayList){
            $GUID = [GUID]::NewGuid()
            if($null -ne $o.Key){$Key = $o.key}else{$Key = $GUID}
            $CurrentInstance = Set-WmiInstance -Namespace "root\cimv2" -class $ClassName -argument @{Key = $Key} 

            foreach($prop in ($o| Get-Member -MemberType NoteProperty | Where-Object {$_.Name -ne "key"})){
                $CurrentInstance.($prop.Name) = $o.($prop.Name)
                $CurrentInstance.Put() | Out-Null
            }
            Write-Output "Added Instance to $ClassName for : " $o
        }
    }
    End{}
}

#region Custom Class Definition
$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "LocalGroup" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Source" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Type" -Value $null

$TemplateObject | Add-Member -MemberType NoteProperty -Name "Session" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserFullName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserDescription" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserMail" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DN" -Value $null

New-WMIClass -ClassName "CustomInventory_LocalAdministrators" -ClassTemplate $TemplateObject
#endregion Custom Class Definition

Try{
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    #region Custom Code
        $LocalSecurityGroupName = "Administrateurs"
        $LocalSecurtiyGroupMember = Get-LocalGroupMember $LocalSecurityGroupName -ErrorAction SilentlyContinue
        
        Foreach($Member in $LocalSecurtiyGroupMember){
            $MyObjectInstance = New-Object PSObject
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Key" -Value $Member.SID
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "LocalGroup" -Value $LocalSecurityGroupName
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Name" -Value $Member.Name
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Source" -Value $Member.PrincipalSource
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Type" -Value $Member.ObjectClass

            #NO AD query if the source is local
            if($Member.PrincipalSource -ne "Local"){
                $UserSearcher = [ADSISearcher]"(&(SamAccountName=$($Member.Name.split("\")[1])))"
                $UserResult = $UserSearcher.FindOne()

                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Session" -Value $null
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserFullName" -Value $UserResult.Properties.displayname
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserDescription" -Value $UserResult.Properties.description
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserMail" -Value $UserResult.Properties.mail
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "DN" -Value $UserResult.Properties.distinguishedname
            }

            #Add Your Object to The ArrayList
            $InstancesObjectArray.Add($MyObjectInstance) | Out-Null
        }
    #endregion Custom Code

    #Convert all object in Array to WMI Instance
    Add-WMIInstances -ClassName "CustomInventory_LocalAdministrators" -ObjectArrayList $InstancesObjectArray

    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory
    return 0 #Script Process With Success (return 0 for SCCM)
}catch{
    Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
    Return -1 #Script Failed  (return -1 for SCCM)
}

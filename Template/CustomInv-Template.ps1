<#
.SYNOPSIS
  <Overview of WMI Class>
.DESCRIPTION
  <Brief description of script and generated WMi Class>
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
  <Example :
    Custom_WMIClassName :: Root\Cimv2
        [String]PropertyName1 : Description
        [String]PropertyName2 : Description
  >
.NOTES
  Version:        1.0
  Author:         <Your Name>
  Creation Date:  <Creation Date>
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
$TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value $null

New-WMIClass -ClassName "CustomClassName" -ClassTemplate $TemplateObject
#endregion Custom Class Definition

Try{
    #region Custom Code
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    <#
    Put your code for generating one or several Instance Object, you need to respect template object Property
    You can Add Key Property value if you want customize it, else a GUID is generated for the instance key
    EXAMPLE :  
    #>
    $MyObjectInstance = New-Object PSObject
    #$MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Key" -Value "CustomKey"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value "SetValue1"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value "SetValue2"

    #Add Your Object to The ArrayList
    $InstancesObjectArray.Add($MyObjectInstance) | Out-Null

    #Convert all object in Array to WMI Instance
    Add-WMIInstances -ClassName "CustomClassName" -ObjectArrayList $InstancesObjectArray
    #endregion Custom Code

    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory
    return 0 #Script Process With Success (return 0 for SCCM)
}catch{
    Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
    Return -1 #Script Failed  (return -1 for SCCM)
}
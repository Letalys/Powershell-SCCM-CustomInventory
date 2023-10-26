<#
.SYNOPSIS
  Create inventory for all object in local Administrator
.DESCRIPTION
  The create a custom inventory of all User administrator on the machine, connecting to Active Directory to retrieving User Information or group information
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
   CustomInventory_UsersProfiles :: Root\Cimv2
        "Localgroup" : Name of local group if admin member is a group
        "Name" : Name of Account
        "Source" : If the group or account is a local or Active Directory
        "Type" : user or group
        "Session" : IF AD Account get Samaccountname
        "Userfullname" : get the fullname of AD USer
        "UserDescription" : get the user or group description of AD USer
        "Usermail" : get the mail of AD USer
        "DN" : get the full DistinguishedName
.NOTES
  Version:        2.0
  Author:         Letalys
  Creation Date:  25/10/2023
  Purpose/Change: Using new template for Windows 7 inventories
.LINK
    Author : Letalys (https://github.com/Letalys)
#>

$VerbosePreference = 'SilentlyContinue'

Function Invoke-CCMHardwareInventory{
    Begin{
     Write-Verbose "Trying to perform CCM hardware inventory..."
    }
    Process{
      Try{
        $GetSMSClient = Get-WmiObject -Class "SMS_Client" -Namespace 'root\ccm' -ErrorAction SilentlyContinue
        if($null -ne $GetSMSClient){
           Write-Verbose "CCM Agent found, performing hardware inventory."

	        $SMSClient = [wmiclass] "\\$($env:COMPUTERNAME)\root\ccm:SMS_Client"
	        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
        }else{
            Write-Verbose "CCM Agent not found, will not perform hardware inventory."
        }
      }Catch{
        Write-Verbose "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
        Break
      }
    }
    End{
      If($?){
       Write-Verbose "Completed Successfully."
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
        if($null -ne (Get-WmiObject $ClassName -ErrorAction SilentlyContinue)){Write-Verbose "Deleting class $ClassName" ; Remove-WmiObject $ClassName}
        Write-Verbose "Create New WMI Class :  $ClassName"

        $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null);
	    $newClass["__CLASS"] = $ClassName;
        $newClass.Qualifiers.Add("Static", $true)

        $newClass.Properties.Add("Key", [System.Management.CimType]::String, $false)
        $newClass.Properties["Key"].Qualifiers.Add("Key", $true)

        $TemplateProperties = $ClassTemplate | Get-Member -MemberType NoteProperty

        foreach($prop in $TemplateProperties){
           Write-Verbose "`t Add Class Property : $($Prop.Name)"
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
            #Create GUID Key
            $GUID = [GUID]::NewGuid()

            if($null -ne $o.Key){$Key = $o.key}else{$Key = $GUID}

            $CurrentObjectPropertiesList = $o | Get-Member -MemberType NoteProperty

            $AddInstance = Set-WmiInstance -Class $ClassName -Arguments @{Key = $key} 

            Write-Verbose "Create Instance with key : $key"

            $GetCurrentAddInstance = Get-WmiObject -Class $ClassName | Where-Object {$_.key -eq $key}
            if($GetCurrentAddInstance -ne $null){
                Write-Verbose  $key 

                foreach($prop in $CurrentObjectPropertiesList){
                    Write-Verbose  "`t $($prop.Name) : $($o.($prop.name))"
                    $GetCurrentAddInstance.($($prop.Name)) = $($o.($prop.name))
                    $GetCurrentAddInstance.put() | Out-null
                  
                }
            }
        }
    }
    End{}
}
Function Test-WMIClass{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName
	)
    $ClassExist  = Get-WmiObject $ClassName -ErrorAction SilentlyContinue
    if($ClassExist  -ne $null){
        Write-Verbose "Return 0 for good execution"
        return 0
    }else{
        Write-Verbose "Return 1 when Class Not create properly"
        return 1
    }
}

#region Custom Class Definition
$CurrentClassName = "CustomInventory_LocalAdministrators"

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
#endregion Custom Class Definition

Try{
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    #region Custom Code
    # Défine Localgroup Admin
    $LocalSecurityGroupName = "Administrateurs"

    # Local ADSI
    $LocalGroup = [ADSI]"WinNT://./$LocalSecurityGroupName,group"
    $LocalGroupMembers = $LocalGroup.Invoke("Members") 
    
    ForEach($Member in $LocalGroupMembers) {
        $MemberName = $Member.GetType().InvokeMember("Name", 'GetProperty', $null, $Member, $null)
        $MemberType = $Member.GetType().InvokeMember("Class", 'GetProperty', $null, $Member, $null)
        $MemberPath = $Member.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $Member, $null)

        $MyObjectInstance = New-Object PSObject
        $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "LocalGroup" -Value $LocalSecurityGroupName
        $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Name" -Value $MemberName
        $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Type" -Value $MemberType

        if($MemberPath -match $env:COMPUTERNAME){
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Source" -Value "Local"
        }else{
            $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Source" -Value "ActiveDirectory"

            $UserSearcher = [ADSISearcher]"(&(sAMAccountName=$MemberName))"
            $UserResult = $UserSearcher.FindOne()
            if ($UserResult -ne $null) {
	    	#Add [0] if neccessary for user result properties, sample : $UserResult.Properties["displayName"][0]
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserFullName" -Value $UserResult.Properties["displayName"]
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserDescription" -Value $UserResult.Properties["description"]
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "UserMail" -Value $UserResult.Properties["mail"]
                $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "DN" -Value $UserResult.Properties["distinguishedName"]
            }
        }

        $InstancesObjectArray.Add($MyObjectInstance) | Out-Null
    }

    #endregion Custom Code

    #Convert all object in Array to WMI Instance
    New-WMIClass -ClassName $CurrentClassName -ClassTemplate $TemplateObject
    Add-WMIInstances -ClassName $CurrentClassName -ObjectArrayList $InstancesObjectArray
    
    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory

    #Test
    Return (Test-WMIClass -ClassName $CurrentClassName)
}catch{
    Write-Host "An error occurred : "
    Write-Host "$($_.InvocationInfo.ScriptLineNumber) : $($_)"

    Write-Verbose $_
    Write-Verbose "Return -1 for general error"
    return -1
}

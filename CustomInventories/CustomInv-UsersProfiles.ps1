<#
.SYNOPSIS
  Create Inventory for User session present in computer
.DESCRIPTION
  The create a custom inventory of all User session on the machine, connecting to Active Directory to retrieving User Information
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
    CustomInventory_UsersProfiles :: Root\Cimv2
        "SSID" : Get the User SSID from the local registry
        "Profile" : Get the User Profile path from the local registry
        "Session" : Get the User session name from the local
        "UserFullName" : Get the User mail from ActiveDirectory
        "UserDescription" : Get the User Description from ActiveDirectory
        "UserMail" : Get the User mail from ActiveDirectory
  >
.NOTES
    You must have rights to read AD from ADSI
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  26/02/2023
  Purpose/Change: Initial script development
.NOTES
  Version:        2.0
  Author:         Letalys
  Creation Date:  31/05/2023
  Purpose/Change: Change the remote connexion to Domain Controler for using ADSISEARCHER.
                  More easier to use and more secure. Correct some variables.
.NOTES
  Version:        2.1
  Author:         Letalys
  Creation Date:  13/10/2023
  Purpose/Change: Add information to get profile folder and user document folder size and if a user arise from local user or AD user.
                  Changing Properties names
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
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfile" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileFolder" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileFolderSizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileDocumentsFolderySizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Source" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADSamAccountName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserFullName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserDescription" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserMail" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADDN" -Value $null

New-WMIClass -ClassName "CustomInventory_UsersProfiles" -ClassTemplate $TemplateObject
#endregion Custom Class Definition

Try{
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    #region Custom Code
        $RegistryKey = "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
        $ProfileList = Get-ChildItem -Path "HKLM:\$RegistryKey"

 	#This not work on WIndows 7, you have to remove the condition lower to determinate User source (Local/AD)
        $LocalUsers = Get-LocalUser

        foreach($RegEntry in $ProfileList){

            $CurrentSID = $RegEntry.Name.Replace("HKEY_LOCAL_MACHINE$($RegistryKey)",$null)
            $CurrentProfilePath = $RegEntry | Get-itemproperty | Select-Object ProfileImagePath

            if(($CurrentProfilePath.ProfileImagePath -like "C:\Users\*") -and -not ($CurrentProfilePath.ProfileImagePath -like "C:\Users\Default*")){
                $CurrentUserProfil = $($CurrentProfilePath.ProfileImagePath).replace("C:\Users\",$null)
                $CurrentUserSID = $CurrentSID

                #Search by ADSI
                $UserSearcher = [ADSISearcher]"(&(objectClass=user)(SamAccountName=$($CurrentUserProfil)))"
                $UserResult = $UserSearcher.FindOne()

                $CreateUserProfilObject = New-Object Psobject
                $CreateUserProfilObject | Add-Member -Name "Key" -membertype Noteproperty -Value $CurrentUserSID
                $CreateUserProfilObject | Add-Member -Name "UserProfile" -membertype Noteproperty -Value $CurrentUserProfil
                $CreateUserProfilObject | Add-Member -Name "UserProfileFolder" -membertype Noteproperty -Value $CurrentProfilePath.ProfileImagePath

                $FullProfilSizeMo = [math]::Round((Get-ChildItem "$($CurrentProfilePath.ProfileImagePath)" -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1Mb,2)
                $CreateUserProfilObject | Add-Member -Name "UserProfileFolderSizeMB" -membertype Noteproperty -Value $FullProfilSizeMo

                if (Test-Path "$($CurrentProfilePath.ProfileImagePath)\Documents") {
                    $FolderPath = "$($CurrentProfilePath.ProfileImagePath)\Documents"
                    $files = Get-ChildItem $FolderPath -Recurse -Force -File -ErrorAction Ignore
                    if ($files) {
                        $FullProfilDocumentSizeMo = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        $CreateUserProfilObject | Add-Member -Name "UserProfileDocumentsFolderySizeMB" -MemberType NoteProperty -Value $FullProfilDocumentSizeMo
                    } else {
                        $CreateUserProfilObject | Add-Member -Name "UserProfileDocumentsFolderySizeMB" -MemberType NoteProperty -Value 0
                    }
                }

                if($CurrentUserProfil -in $LocalUsers.Name){
                    $CreateUserProfilObject | Add-Member -Name "Source" -membertype Noteproperty -Value "Local"
                }else{
                    $CreateUserProfilObject | Add-Member -Name "Source" -membertype Noteproperty -Value "ActiveDirectory"
                    $CreateUserProfilObject | Add-Member -Name "ADSamAccountName" -membertype Noteproperty -Value $UserResult.Properties.samaccountname
                    $CreateUserProfilObject | Add-Member -Name "ADUserFullName" -membertype Noteproperty -Value  $UserResult.Properties.displayname
                    $CreateUserProfilObject | Add-Member -Name "ADUserDescription" -membertype Noteproperty -Value  $UserResult.Properties.description
                    $CreateUserProfilObject | Add-Member -Name "ADUserMail" -membertype Noteproperty -Value  $UserResult.Properties.mail
                    $CreateUserProfilObject | Add-Member -Name "ADDN" -membertype Noteproperty -Value  $UserResult.Properties.distinguishedname                    
                }

                #Add Your Object to The ArrayList
                $InstancesObjectArray.Add($CreateUserProfilObject) | Out-Null
            }
        
        }        
    #endregion Custom Code

    #Convert all object in Array to WMI Instance
    Add-WMIInstances -ClassName "CustomInventory_UsersProfiles" -ObjectArrayList $InstancesObjectArray
    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory
    return 0 #Script Process With Success (return 0 for SCCM)
}catch{
    Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
    Return -1 #Script Failed  (return -1 for SCCM)
}

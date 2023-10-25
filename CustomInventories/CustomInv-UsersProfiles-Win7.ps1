<#
.SYNOPSIS
  Create Inventory for User session present in computer (Windows 7)
.DESCRIPTION
  The create a custom inventory of all User session on the machine, connecting to Active Directory to retrieving User Information
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
    CustomInventory_UsersProfiles :: Root\Cimv2
        "Key" : User Account SSID
        "UserProfile" : Name of Account
        "UserProfileFolder" : Path to user profile
        "UserProfileFolderSizeMB" : Size of User profile
        "UserProfileDocumentsFolderySizeMB" : Size of Document folder
        "UserProfileMusicFolderySizeMB" : Size of Music Folder
        "UserProfileVideosFolderySizeMB" : Size of Video Folder
        "UserProfilePicturesFolderySizeMB" : Size of Picture folder
        "Source" : Local or Active Directory account
        "ADSamAccountName" : AD Samaccount Name
        "ADUserFullName" : Userfull name from active Directory
        "ADUserDescription" : Userfull name from active Directory
        "ADUserMail" : User mail from Active Directory
        "ADDN" : Distinguished Name from Active Directoy 

.NOTES
    You must have rights to read AD from ADSI.
    The sizes returned may not be accurate because certain system files and folders are not taken into account during calculations 
    But that leaves a good estimate
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
.NOTES
  Version:        2.2
  Author:         Letalys
  Creation Date:  24/10/2023
  Purpose/Change: Add some information about folder profile size. Using WMIObject for working in Windows 7. 
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
$CurrentClassName = "CustomInventory_UsersProfiles"
$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfile" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileFolder" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileFolderSizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileDocumentsFolderySizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileMusicFolderySizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfileVideosFolderySizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserProfilePicturesFolderySizeMB" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Source" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADSamAccountName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserFullName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserDescription" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADUserMail" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "ADDN" -Value $null
#endregion Custom Class Definition

Try{
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    #region Custom Code
        $RegistryKey = "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
        $ProfileList = Get-ChildItem -Path "HKLM:\$RegistryKey"

 	    #This not work on WIndows 7, you have to remove the condition lower to determinate User source (Local/AD)
        $LocalUsers = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount=True"

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

                $FullProfilSizeMo = [math]::Round((Get-ChildItem "$($CurrentProfilePath.ProfileImagePath)" -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1Mb,2)
                $CreateUserProfilObject | Add-Member -Name "UserProfileFolderSizeMB" -membertype Noteproperty -Value $FullProfilSizeMo

                if (Test-Path "$($CurrentProfilePath.ProfileImagePath)\Documents") {
                    $FolderPath = "$($CurrentProfilePath.ProfileImagePath)\Documents"
                    $files = Get-ChildItem $FolderPath -Recurse  -Force  -ErrorAction SilentlyContinue
                    if ($files) {
                        $FullProfilDocumentSizeMo = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        $CreateUserProfilObject | Add-Member -Name "UserProfileDocumentsFolderySizeMB" -MemberType NoteProperty -Value $FullProfilDocumentSizeMo
                    } else {
                        $CreateUserProfilObject | Add-Member -Name "UserProfileDocumentsFolderySizeMB" -MemberType NoteProperty -Value 0
                    }
                }

                if (Test-Path "$($CurrentProfilePath.ProfileImagePath)\Videos") {
                    $FolderPath = "$($CurrentProfilePath.ProfileImagePath)\Videos"
                    $files = Get-ChildItem $FolderPath -Recurse  -Force  -ErrorAction SilentlyContinue
                    if ($files) {
                        $FullProfilVideosSizeMo = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        $CreateUserProfilObject | Add-Member -Name "UserProfileVideosFolderySizeMB" -MemberType NoteProperty -Value $FullProfilVideosSizeMo
                    } else {
                        $CreateUserProfilObject | Add-Member -Name "UserProfileVideosFolderySizeMB" -MemberType NoteProperty -Value 0
                    }
                }

                if (Test-Path "$($CurrentProfilePath.ProfileImagePath)\Music") {
                    $FolderPath = "$($CurrentProfilePath.ProfileImagePath)\Music"
                    $files = Get-ChildItem $FolderPath -Recurse  -Force  -ErrorAction SilentlyContinue
                    if ($files) {
                        $FullProfilMusicSizeMo = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        $CreateUserProfilObject | Add-Member -Name "UserProfileMusicFolderySizeMB" -MemberType NoteProperty -Value $FullProfilMusicSizeMo
                    } else {
                        $CreateUserProfilObject | Add-Member -Name "UserProfileMusicFolderySizeMB" -MemberType NoteProperty -Value 0
                    }
                }

                if (Test-Path "$($CurrentProfilePath.ProfileImagePath)\Pictures") {
                    $FolderPath = "$($CurrentProfilePath.ProfileImagePath)\Pictures"
                    $files = Get-ChildItem $FolderPath -Recurse  -Force  -ErrorAction SilentlyContinue
                    if ($files) {
                        $FullProfilPicturesSizeMo = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                        $CreateUserProfilObject | Add-Member -Name "UserProfilePicturesFolderySizeMB" -MemberType NoteProperty -Value $FullProfilPicturesSizeMo
                    } else {
                        $CreateUserProfilObject | Add-Member -Name "UserProfilePicturesFolderySizeMB" -MemberType NoteProperty -Value 0
                    }
                }

                if($LocalUsers.Name -Contains $CurrentUserProfil){
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

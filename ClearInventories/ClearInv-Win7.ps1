<#
.SYNOPSIS
  Deleted List of WMI CLass and instance
.DESCRIPTION
  This script is for detroy unwanted or useless WMI Class.
  Be carrefeull when you do This, Destroy System class can made several damage to your system.
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  27/10/2023
  Purpose/Change: Initial
.LINK
    Author : Letalys (https://github.com/Letalys)
#>

$VerbosePreference = 'SilentlyContinue'

Function Remove-WMIInstance{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName
	)
    
    Write-Verbose "Deleting class $Classname ..."

    if ($null -ne (Get-WmiObject $ClassName -ErrorAction SilentlyContinue)) {
        try{
            Remove-WmiObject $ClassName
        }catch{
            Write-Verbose "$Classname Error : $($_)"
        }

    }
    else {
        Write-Verbose "$ClassName not exist"
    }

}

Try{
     $ClassNameList = @(
        "ClassName1",
        "ClassName2"
    )

    foreach($ClassName in $ClassNameList){
        Remove-WMIInstance -ClassName $ClassName
    }
     return 0
}catch{
    Write-Host "An error occurred : "
    Write-Host "$($_.InvocationInfo.ScriptLineNumber) : $($_)"

    Write-Verbose $_
    Write-Verbose "Return -1 for general error"
    return -1
}

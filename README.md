
# Powershell : SCCM Create Custom Inventory

These scripts can be used in the SCCM console compliance settings to generate new WMI classes and instances on computers to be collected by CCM client hardware inventories.

## Template 

You can use the template file to generate your own WMI classes and instances that can be collected by the CCM agent hardware inventory.

| Script    |
|-----------|
| [Template/CustomInv-Template.ps1](./Template/CustomInv-Template.ps1) |

### How To use the template

1. **Generate your Class Template** (l.105)
    
    ```
    #region Custom Class Definition
    $TemplateObject = New-Object PSObject
    $TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value $null
    $TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value $null

    New-WMIClass -ClassName "CustomClassName" -ClassTemplate $TemplateObject
    #endregion Custom Class Definition
    ```
- Use only `-MemberType Noteproperty` to create your custom properties
- Change the ClassName in `New-WMIClass -ClassName "CustomClassName" -ClassTemplate $TemplateObject`

2. **Generate your own code** (Begin at l.113)

   Create your ArrayList that will host all your WMI instances
   ```
   [System.Collections.Arraylist]$InstancesObjectArray =@()
   ```

   Your instances Object must have the same property of your Template Object, but you can add a special property ***"Key"*** if you want customize his value. By Default de ***Key*** Property of instance is a GUID.

   ```
    $MyObjectInstance = New-Object PSObject
    #(Optional) $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Key" -Value "CustomKey"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value "SetValue1"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value "SetValue2"
   ```
   Add all your Object for a class into your ArrayList


3. Generate WMI Instances

Use the function below to generate all WMI Instance. 
***don't forget to change the className***

```
Add-WMIInstances -ClassName "CustomClassName" -ObjectArrayList $InstancesObjectArray
```




## SCCM Compliance Settings

1. Create new Configuration item
    - Set a Configuration item Name and description
    - Select your supported plateform for your configuration item
    - In Settings, add new Setting, set Name and Description and select **SettingType = Script** and **DataType = Integer**
    - Put your CustomInventory Script into **Discovery Script**
    - In Compliance rules, **Add** New Rule
        - Set Name and Description for the rules
        - Select **RuleType = value**
        - Select **Operator = Equals**
        - Set **Folowwing Value** to **0** (It's the value return by script when ran is OK)
- Complete the Item Configuration Window

2. Create a new configuration baseline
    - Set a baseline name and description
    - In **Configuration Data** add *Configuration Item*
    - Select your Item configuration for CustomInventory

3. Deploy Your BaseLine in to Device Collection

4. In Administration Panel > Client Settings > Default Client Settings
    - In Hardware Invetory Setting, You need to add the new WMI Class > **Set Classes**
    - Click **Add** and click **Connect**
    - Select your WMI Namespace and **Connect**
    - Now Select your new wmi class (if you have run th script first on your machine),
    - Click OK and uncheck on the main WMI Class list which where invotoried by CCM agent.

5. In your real Client Settings
    - In Hardware Inventory, **Set Classes**, you can now re-select your class and the property you want.

    

## Ready To Use Scripts

If you want, you can use ready-to-use scripts :

|Script|Description|
|-|-|
|[CustomInventories/CustomInv_PnPDrivers.ps1](./CustomInventories/CustomInv-PnPDrivers.ps1)| Generate SCCM inventory for all PnpSignedDrivers |
|[CustomInventories/CustomInv-UsersProfiles.ps1](./CustomInventories/CustomInv-UsersProfiles.ps1)| Get all User Session which is created on a machine and connect to AD to get more information about them |
|[CustomInventories/CustomInv_OracleClient.ps1](./CustomInventories/CustomInv-OracleClient.ps1)| Generate SCCM inventory for obtains information about Oracle Client (Install by OUI) |
|[CustomInventories/CustomInv_LocalAdmin.ps1](./CustomInventories/CustomInv-LocalAdmin.ps1)| Generate SCCM inventory to retrieve who is Admininistrator Local of the computers and collect User informations |



## 🔗 Links
https://github.com/Letalys/Powershell-SCCM-CustomInventory


## Autor
- [@Letalys (GitHUb)](https://www.github.com/Letalys)

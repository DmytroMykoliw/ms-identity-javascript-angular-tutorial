[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [Parameter(Mandatory = $False, HelpMessage = 'Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId,
    [Parameter(Mandatory = $False, HelpMessage = 'Azure environment to use while running the script (it defaults to AzureCloud)')]
    [string] $azureEnvironmentName
)

$ErrorActionPreference = "Stop"
<#.Description
    This function generates groups names
#> 
Function GetGroupName([int] $val) {

    if ($val -lt 10) {
        $groupName = "Test Group 00" + $val;
    }
    elseif ($val -lt 100) { 
        $groupName = "Test Group 0" + $val;
    }
    else {
        $groupName = "Test Group " + $val;
    }

    return $groupName;
}

<#.Description
    This function creates security groups and assigns the user to the security groups
#>
Function CreateGroupsAndAssignUser($user) 
{
    $val = 1;
     
    while ($val -ne 223) 
    {
        $groupName = GetGroupName -val $val
        $group = Get-MgGroup -Filter "DisplayName eq '$groupName'"
        $groupNameLower =  $groupName.ToLower();
        $nickName = $groupNameLower.replace(' ','');

        if ($group) 
        {
            Write-Host "Group $($group.DisplayName) already exists"
        }
        else
        {
            $newsg = New-MgGroup -DisplayName $groupName -MailEnabled:$False -MailNickName $nickName  -SecurityEnabled
            Write-Host "Successfully created group '$($newsg.DisplayName)'"            
            $userId = $user.Id
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$userId}"
            }

            New-MgGroupMemberByRef -GroupId $newsg.Id -BodyParameter $params
            Write-Host "Successfully assigned user to group '$($newsg.DisplayName)'"
        }
       
        $val += 1;
    }

}

<#.Description
    This function signs in the user to the tenant using Graph SDK.
    Add the user object_id below to assign the user the groups
#> 
Function ConfigureApplications 
{

    if (!$azureEnvironmentName) {
        $azureEnvironmentName = "Global"
    }

    Write-Host "Connecting to Microsoft Graph"
    if ($tenantId -eq "") {
        Connect-MgGraph -Scopes "User.Read.All Group.ReadWrite.All GroupMember.ReadWrite.All" -Environment $azureEnvironmentName
        $tenantId = (Get-MgContext).TenantId
    }
    else {
        Connect-MgGraph -TenantId $tenantId -Scopes "User.Read.All Group.ReadWrite.All GroupMember.ReadWrite.All" -Environment $azureEnvironmentName
    }

    # Add user object Id here
    $usersobjectId = Read-Host -Prompt "Enter the object Id (from Azure portal) of the user who will assigned to these security groups: "

    $user = Get-MgUser -UserId $usersobjectId 

    Write-Host 'Found user -' 
    $user | Format-List  ID, DisplayName, Mail, UserPrincipalName

    CreateGroupsAndAssignUser -user $user
}

if ($null -eq (Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication")) {
    Install-Module "Microsoft.Graph.Authentication" -Scope CurrentUser
    Write-Host "Installed Microsoft.Graph.Authentication module. If you are having issues, please create a new PowerShell session and try again."
}

Import-Module Microsoft.Graph.Authentication

if ($null -eq (Get-Module -ListAvailable -Name "Microsoft.Graph.Groups")) {
    Install-Module "Microsoft.Graph.Groups" -Scope CurrentUser
    Write-Host "Installed Microsoft.Graph.Groups module. If you are having issues, please create a new PowerShell session and try again."
}

Import-Module Microsoft.Graph.Groups

if ($null -eq (Get-Module -ListAvailable -Name "Microsoft.Graph.Users")) {
    Install-Module "Microsoft.Graph.Users" -Scope CurrentUser
    Write-Host "Installed Microsoft.Graph.Users module. If you are having issues, please create a new PowerShell session and try again."
}

Import-Module Microsoft.Graph.Users

try 
{
    ConfigureApplications -tenantId $tenantId -environment $azureEnvironmentName
}
catch 
{
    $_.Exception.ToString() | out-host
    $message = $_
    Write-Warning $Error[0]
    Write-Host "Unable to register apps. Error is $message." -ForegroundColor White -BackgroundColor Red
}

Write-Host "Disconnecting from tenant"
Disconnect-MgGraph
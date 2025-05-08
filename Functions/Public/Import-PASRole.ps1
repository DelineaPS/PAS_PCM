###########
#region ### global:Import-PASRole # CMDLETDESCRIPTION : Imports PAS Roles from another PAS tenant :
###########
function global:Import-PASRole
{
    <#
    .SYNOPSIS
    Imports a PAS Role from another PAS tenant.

    .DESCRIPTION
    This cmdlet will Import a PAS Role from another Delinea Privilege Access Service tenant. This requires two PAS tenants.

    First on the old PAS tenant, get the Roles you want to import with "Get-PASRole". Save these to a variable

    Then, connect to the new PAS tenant, and use this cmdlet to recreate the role, along with all members and administrative
    rights. UNIX Profile is not suported at this time.

    This also requires that you have Connectors pointed to the same AD domain. This is to ensure that the AD lookup of any
    AD principals works correctly. For example:

    TenantA.my.centrify.net is pointed to mydomain.com
    TenantB.my.centrify.net is also pointed to mydomain.com

    First connect to TenantA.my.centrify.net. Then run "$myroles = Get-PASRole".

    Then connect to TenantB.my.centrify.net. Then run "Import-PASRole -PASRole $myroles"

    If Connectors are registered in both tenants, then all non-default roles will be recreated in TenantB.my.centrify.net with
    the principals and administrative rights recreated.

    If a principal is from Federation, then the Federated Name (SourceDsLocalized) need to match.

    .PARAMETER PASRoles
    The PASRole objects to import.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function only prints to the console.

    .EXAMPLE
    C:\PS> Import-PASRole -PASRoles $pasroles
    For each PAS role specified in $pasroles, attempt to recreate the role, members, and administrative rights in the 
    connected Delinea PAS tenant.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = "The PASRoles to import.")]
        [PASRole[]]$PASRoles
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # getting rid of default roles if they are in here
    $ImportedRoles = $PASRoles      | Where-Object -Property Name -notmatch '^(Centrify Agent Computers)|(Invited Users)|(Technical Support Access)|(System Administrator)$'
    $ImportedRoles = $ImportedRoles | Where-Object -Property ID -notmatch '^Everybody$'

    # for each role
    foreach ($pasrole in $ImportedRoles)
    {
        Write-Verbose ("RoleExistCheck [{0}]" -f $pasrole.Name)

        # get the existing role
        $existingrole = Get-PASRole -Name $pasrole.Name

        # if the role doesn't exist
        if (!$existingrole)
        {
            Try # to make it
            {
                Write-Host ("Creating Role [{0}] ... " -f $pasrole.Name) -NoNewline
                $call = Invoke-PASAPI -APICall SaasManage/StoreRole -Body (@{Name=$pasrole.Name;Description=$pasrole.Description} | ConvertTo-Json)
                Write-Host ("Done!") -ForegroundColor Green
            }
            Catch
            {
                Write-Host ("Error!") -ForegroundColor Red
                # if an error occurred during creating the role, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New Role object.")
				$e.AddExceptionData($_)
				$e.AddData("call",$call)
				$e.AddData("roleid",$roleid)
                $e
            }# Catch
        }# if (!$existingrole)
    }# foreach ($pasrole in $PASRoles)

    # now that the role exists do a member update and administrative right update

    # for each role we imported
    foreach ($pasrole in $ImportedRoles)
    {
        Write-Host ("Working Role [{0}]" -f $pasrole.Name)
        # get the existing role
        $existingrole = Get-PASRole -Name $pasrole.Name

        # booleans to determine if an update is actually needed or not
        [System.Boolean]$RoleNeedPrincipalUpdate  = $false
        [System.Boolean]$RoleNeedAdminRightUpdate = $false

        # starting the jsonbody
        $jsonbody = @{}
        $jsonbody.Name = $existingrole.ID
        $jsonbody.Description = $pasrole.Description
    
        Try # to find and prepare the missing user principals
        {
            # userbank for missing users
            $userbank = New-Object System.Collections.ArrayList

            # getting the missing user principals
            $missingusers = Compare-Object $pasrole.RoleMembers $existingrole.RoleMembers -Property Name,DirectoryService -PassThru | Where-Object {$_.Type -eq "User" -and $_.SideIndicator -eq "<="}
            
            # for each missing user
            foreach ($user in $missingusers)
            {
                # set our flag to update
                $RoleNeedPrincipalUpdate = $true
                Write-Host ("- querying missing user [{0}] from [{1}]" -f $user.Name, $user.DirectoryService)

                # query the ID of the user from this directory service
                $userquery = Query-RedRock -SQLQuery ("SELECT ID FROM User WHERE Username = '{0}' AND SourceDsLocalized = '{1}'" -f $user.Name, $user.DirectoryService) | Select-Object -ExpandProperty ID

                # add the ID to our userbank
                $userbank.Add($userquery) | Out-Null
            }# foreach ($user in $missingusers)

        }# Try # to find and prepare the missing user principals
        Catch
        {
            # if an error occurred during updating the role with users, create a new PASException and return that with the relevant data
            $e = New-Object PASPCMException -ArgumentList ("Error during User Update Role object.")
            $e.AddExceptionData($_)
            $e.AddData("jsonbody",$jsonbody)
            $e.AddData("user",$user)
            $e
        }# Catch

        Try # to find and prepare the missing group principals
        {
            # userbank for missing groups
            $groupbank = New-Object System.Collections.ArrayList

            # getting the missing user principals
            $missinggroups = Compare-Object $pasrole.RoleMembers $existingrole.RoleMembers -Property Name,DirectoryService -PassThru | Where-Object {$_.Type -eq "Group" -and $_.SideIndicator -eq "<="}
        
            # for each missing group
            foreach ($group in $missinggroups)
            {
                # set our flag to update
                $RoleNeedPrincipalUpdate = $true
                Write-Host ("- querying missing group [{0}] from [{1}]" -f $group.Name, $group.DirectoryService)

                # query the ID of the group from this directory service
                $groupquery = Query-RedRock -SQLQuery ("SELECT InternalName FROM DsGroups WHERE SystemName LIKE '%{0}%' AND ServiceInstanceLocalized = '{1}'" -f $group.Name, $group.DirectoryService) | Select-Object -ExpandProperty InternalName
                
                # add the ID to our groupbank
                $groupbank.Add($groupquery) | Out-Null
            }# foreach ($group in $missinggroups)

        }# Try # to find and prepare the missing group principals
        Catch
        {
            # if an error occurred during updating the role with groups, create a new PASException and return that with the relevant data
            $e = New-Object PASPCMException -ArgumentList ("Error during Group Update Role object.")
            $e.AddExceptionData($_)
            $e.AddData("jsonbody",$jsonbody)
            $e.AddData("group",$group)
            $e
        }# Catch

        Try # to find and prepare the missing role principals
        {
            # userbank for missing role
            $rolebank = New-Object System.Collections.ArrayList

            # getting the missing role principals
            $missingroles = Compare-Object $pasrole.RoleMembers $existingrole.RoleMembers -Property Name,DirectoryService -PassThru | Where-Object {$_.Type -eq "Role" -and $_.SideIndicator -eq "<="}
        
            # for each missing role
            foreach ($role in $missingroles)
            {
                # set our flag to update
                $RoleNeedPrincipalUpdate = $true
                Write-Host ("- querying missing role [{0}] from [{1}]" -f $role.Name, $role.DirectoryService)

                # query the ID of the role from this directory service
                $rolequery = Query-RedRock -SQLQuery ("SELECT ID FROM Role WHERE Name = '{0}'" -f $role.Name) | Select-Object -ExpandProperty ID

                # add the ID to our rolebank
                $rolebank.Add($rolequery) | Out-Null
            }# foreach ($role in $missingroles)
        }# Try # to find and prepare the missing tole principals
        Catch
        {
            # if an error occurred during updating the role with roles, create a new PASException and return that with the relevant data
            $e = New-Object PASPCMException -ArgumentList ("Error during Role Update Role object.")
            $e.AddExceptionData($_)
            $e.AddData("jsonbody",$jsonbody)
            $e.AddData("role",$role)
            $e
        }# Catch

        Try # to finalize the jsonbody and update the role with these members
        {
            # adding in our user principals
            $users           = @{}
            $users.Add       = $userbank
            $jsonbody.Users  = $users

            # adding in our group principals
            $groups          = @{}
            $groups.Add      = $groupbank
            $jsonbody.Groups = $groups

            # adding in our role principals
            $roles           = @{}
            $roles.Add       = $rolebank
            $jsonbody.Roles  = $roles

            # if an update flag was set
            if ($RoleNeedPrincipalUpdate)
            {
                # attempt to update the role
                Write-Host ("Updating Principal Members in Role [{0}] ... " -f $existingrole.Name) -NoNewline
                $memberupdates = Invoke-PASAPI -APICall Roles/UpdateRole -Body ($jsonbody | ConvertTo-Json)
                Write-Host ("Done!") -ForegroundColor Green
            }
            else
            {
                Write-Host ("No principals to update in role [{0}]" -f $existingrole.Name)
            }
        }# Try # to finalize the jsonbody and update the role with these members
        Catch
        {
            Write-Host ("Error!") -ForegroundColor Red
            # if an error occurred during updating the role, create a new PASException and return that with the relevant data
            $e = New-Object PASPCMException -ArgumentList ("Error during Update Role object.")
            $e.AddExceptionData($_)
            $e.AddData("jsonbody",$jsonbody)
            $e.AddData("memberupdates",$memberupdates)
            $e
        }# Catch

        Try # to find prepare and update the administrative rights
        {
            # rightsbank for missing rights
            $rightbank = New-Object System.Collections.ArrayList

            # getting the missing rights
            $missingrights = Compare-Object $pasrole.AdministrativeRights $existingrole.AdministrativeRights -Property Path -PassThru | Where-Object -Property SideIndicator -eq "<="
        
            # for each missing right
            foreach ($right in $missingrights)
            {
                # set our flag to update
                $RoleNeedAdminRightUpdate = $true
                Write-Host ("- querying missing right [{0}]" -f $right.Description)

                # prepare the jsonbody
                $obj = @{}
                $obj.Path = $right.Path
                $obj.Role = $existingrole.ID

                # add the special hasttable to our rightbank
                $rightbank.Add($obj) | Out-Null
            }#  foreach ($right in $missingrights)

            # if an update flag was set
            if ($RoleNeedAdminRightUpdate)
            {
                # attempt to update the role
                Write-Host ("Updating Administrative Rights in Role [{0}] ... " -f $existingrole.Name) -NoNewline
                $assignrights = Invoke-PASAPI -APICall SaasManage/AssignSuperRights -Body ($rightbank | ConvertTo-Json)
                Write-Host ("Done!") -ForegroundColor Green
            }
            else
            {
                Write-Host ("No administrative rights to update in role [{0}]" -f $existingrole.Name)
            }
        }# Try # now try to update the rights
        Catch
        {
            # if an error occurred during updating the role, create a new PASException and return that with the relevant data
            $e = New-Object PASPCMException -ArgumentList ("Error during Admin Right Update Role object.")
            $e.AddExceptionData($_)
            $e.AddData("rightbank",$rightbank)
            $e.AddData("assignrights",$assignrights)
            $e
        }# Catch
    }# foreach ($pasrole in $ImportedRoles)    
}# function global:Import-PASRole
#endregion
###########
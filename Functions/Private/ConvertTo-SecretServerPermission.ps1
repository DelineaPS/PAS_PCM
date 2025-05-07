
###########
#region ### global:ConvertTo-SecretServerPermissions # Converts RowAce data into Secret Server equivalent
###########
function global:ConvertTo-SecretServerPermission
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Type")]
        [ValidateSet("Self","Set","Folder","SetMember")]
        $Type,

        [Parameter(Mandatory = $true, HelpMessage = "Name")]
        $Name,

        [Parameter(Mandatory = $true, HelpMessage = "The JSON roles to prepare.")]
        $RowAce
    )

    if ($RowAce.PASPermission.GrantString -match "(Grant|Owner)")
    {
        $perms = "Owner"
    }
    elseif ($RowAce.PASPermission.GrantString -match '(Checkout|Retrieve|Naked)')
    {
        $perms = "View"
    }
    elseif ($RowAce.PASPermission.GrantString -like "*Edit*")
    {
        $perms = "Edit"
    }
    else
    {
        $perms = "None"
    }

    $permission = New-Object MigratedPermission -ArgumentList ($Type,$Name,$RowAce.PrincipalType,$RowAce.PrincipalName,$RowAce.isInherited,$perms,$RowAce.PASPermission.GrantString)

    return $permission
}# function global:ConvertTo-SecretServerPermissions
#endregion
###########
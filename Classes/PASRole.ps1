# class to hold PAS Roles
[NoRunspaceAffinity()]
class PASRole
{
    [System.String]$Name
    [System.String]$ID
    [System.String]$Description
    [System.String]$DirectoryServiceUuid
    [System.Collections.ArrayList]$RoleMembers = @{}
    [System.Collections.ArrayList]$AdministrativeRights = @{}

    # empty constructor
    PASRole () {}

	# primary constructor
    PASRole([System.String]$n, [System.String]$i, [System.String]$de, [System.String]$du)
    {
        $this.Name                 = $n
        $this.ID                   = $i
        $this.Description          = $de
        $this.DirectoryServiceUuid = $du
    }

    [void] addMember($rolemember)
    {
        $this.RoleMembers.Add($rolemember) | Out-Null
    }

    [void] removeMember($rolemember)
    {
        $this.RoleMembers.Remove($rolemember) | Out-Null
    }

    [void] addAdministrativeRight($right)
    {
        $this.AdministrativeRights.Add($right) | Out-Null
    }

    [void] removeAdministrativeRight($right)
    {
        $this.AdministrativeRights.Remove($right) | Out-Null
    }
}# class PASRole

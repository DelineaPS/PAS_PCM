# class to hold migrated permissions
[NoRunspaceAffinity()]
class MigratedPermission
{
    [System.String]$PermissionType
    [System.String]$PermissionName
    [System.String]$PrincipalType
    [System.String]$PrincipalName
    [System.Boolean]$isInherited
    [System.String]$Permissions
    [System.String]$OriginalPermissions

    # constructor for reserialization
	MigratedPermission ($pasobject)
    {
        # for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# MigratedPermission ($pasobject) 

	# primary constructor
    MigratedPermission([System.String]$pt, [System.String]$pn, [System.String]$prt, [System.String]$prn, `
               [System.String]$ii, [System.String[]]$p, [System.String[]]$op)
    {
        $this.PermissionType      = $pt
        $this.PermissionName      = $pn
        $this.PrincipalType       = $prt
        $this.PrincipalName       = $prn
        $this.isInherited         = $ii
        $this.Permissions         = $p
        $this.OriginalPermissions = $op
    }# MigratedPermission([System.String]$pt, [System.String]$pn, [System.String]$prt, [System.String]$prn, `
}# class MigratedPermission
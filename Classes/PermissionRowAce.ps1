# class for holding RowAce information
[NoRunspaceAffinity()]
class PermissionRowAce
{
    [System.String]$PrincipalType  # the principal type
    [System.String]$PrincipalUuid  # the uuid of the prinicpal
    [System.String]$PrincipalName  # the name of the principal
    [System.Boolean]$isInherited   # determines if this permission is inherited
	[System.String]$InheritedFrom  # if inherited, displays where this permission is inheriting from
    [PSCustomObject]$PASPermission # the PASpermission object
	hidden [System.String]$PASPCMObjectType
	
	# empty constructor
	PermissionRowAce () {}

	# method for reserialization
	resetObject ($pasobject)
	{
		# for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# resetObject ($pasobject)

	# primary constructor
    PermissionRowAce([System.String]$pt, [System.String]$puuid, [System.String]$pn, `
                   [System.Boolean]$ii, [System.String]$if, [PSCustomObject]$pp)
    {
		$this.PASPCMObjectType = "PermissionRowAce"
        $this.PrincipalType = $pt
        $this.PrincipalUuid = $puuid
        $this.PrincipalName = $pn
        $this.isInherited   = $ii
		$this.InheritedFrom = $if
        $this.PASPermission = $pp
    }# PASRowAce([System.String]$pt, [System.String]$puuid, [System.String]$pn, `
}# class PASRowAce
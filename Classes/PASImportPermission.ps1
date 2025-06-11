# class for holding Permission information for importing into another PAS tenant
# a human readable format
[NoRunspaceAffinity()]
class PASImportPermission
{
    [System.String]$Principal   # the name of principal
    [System.String]$PType       # the type of principal, User, Group, or Role
    [System.String]$Rights      # the rights to assign
    [System.String]$PrincipalId # the uuid of the principal

	# empty constructor
	PASImportPermission () {}

	#primary constructor
    PASImportPermission ([PSObject]$pra)
    {
        $this.Principal        = $pra.PrincipalName
        $this.PType            = $pra.PrincipalType
        $this.Rights           = $pra.PASPermission.GrantString
        $this.PrincipalId      = $pra.PrincipalUuid
    }# PASImportPermission ([PSObject]$pra)

    updatePrincipalId()
    {   
        $uuid = $null
        
        $uuid = Invoke-Expression -Command ('$uuid = Search-PASDirectory -{0} "{1}" | Select-Object -ExpandProperty ID' -f $this.PType, $this.Principal)

        $this.PrincipalId = $uuid
    }
}# class PASImportPermission
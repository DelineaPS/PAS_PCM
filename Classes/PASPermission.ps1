# class for holding Permission information including converting it to
# a human readable format
[NoRunspaceAffinity()]
class PASPermission
{
    [System.String]$Type        # the type of permission (Secret, Account, etc.)
    [System.Int64]$GrantInt     # the Int-based number for the permission mask
    [System.String]$GrantBinary # the binary string of the the permission mask
    [System.String]$GrantString # the human readable permission mask

	# constructor for reserialization
    PASPermission ($pasobject)
    {
        # for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# PASPermission ($pasobject) 

    PASPermission ([System.String]$t, [System.Int64]$gi, [System.String]$gb)
    {
        $this.Type        = $t
        $this.GrantInt    = $gi
        $this.GrantBinary = $gb
        $this.GrantString = Convert-PermissionToString -Type $t -PermissionInt ([System.Convert]::ToInt64($gb,2))
    }# PASPermission ([System.String]$t, [System.Int64]$gi, [System.String]$gb)
}# class PASPermission
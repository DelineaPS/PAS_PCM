# class to hold PASSystems
[NoRunspaceAffinity()]
class PASSystem
{
    [System.String]$Name
    [System.String]$ID
    [System.String]$Description
    [System.String]$FQDN
    [System.String]$ComputerClass
    [System.String]$SessionType
    [PSCustomObject[]]$PermissionRowAces # The RowAces (Permissions) of this System
    [System.Collections.ArrayList]$MembersUuid = @{} # the Uuids of the members
    [System.Collections.ArrayList]$PASAccounts = @{} 
    hidden [System.String]$PASPCMObjectType

	# empty constructor
    PASSystem() {}

    # primary constructor
    PASSystem($q)
    {
        $this.PASPCMObjectType = "PASSystem"
        $this.Name             = $q.Name
        $this.ID               = $q.ID
        $this.Description      = $q.Description
        $this.FQDN             = $q.FQDN
        $this.ComputerClass    = $q.ComputerClass
        $this.SessionType      = $q.SessionType

        # getting the RowAces for this Set
        $this.PermissionRowAces = Get-PASRowAce -Type "Server" -Uuid $this.ID

        # getting member uuids
        $this.MembersUuid.AddRange(@(Query-RedRock -SQLQuery ("SELECT ID FROM VaultAccount WHERE Host = '{0}'" -f $this.ID) | Select-Object -ExpandProperty ID)) | Out-Null
    }

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

    getAccounts()
    {
        if ($this.MembersUuid -ne $null)
        {
            $this.PASAccounts.AddRange(@(Get-PASAccount -Uuid $this.MembersUuid)) | Out-Null
        }
    }
}# class PASSystem
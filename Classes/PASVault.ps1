# class for configured Vaults
[NoRunspaceAffinity()]
class PASVault
{
    [System.String]$VaultType
    [System.String]$VaultName
    [System.String]$ID
    [System.String]$Url
    [System.String]$Username
    [System.Int32]$SyncInterval
    [System.DateTime]$LastSync
	hidden [System.String]$PASPCMObjectType

	# empty constructor
    PASVault () {}

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
    PASVault($vault)
    {
		$this.PASPCMObjectType = "PASVault"
        $this.VaultType = $vault.VaultType
        $this.VaultName = $vault.VaultName
        $this.ID = $vault.ID

        if ($vault.LastSync -ne $null)
        {
            $this.LastSync = $vault.LastSync
        }

        $this.SyncInterval = $vault.SyncInterval
        $this.Username = $vault.Username
        $this.Url = $vault.Url
    }# PASVault($vault)
}# class PASVault

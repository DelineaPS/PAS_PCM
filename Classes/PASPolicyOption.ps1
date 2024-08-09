# class to hold Policy Options
[NoRunspaceAffinity()]
class PASPolicyOption
{
	[System.String]$PolicyOption
	[System.String]$fromPolicy
	[PSObject]$PolicyValue
	hidden [System.String]$PASPCMObjectType

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
	PASPolicyOption([System.String]$po, [System.String]$fp, [PSObject]$pv) 
	{
		$this.PASPCMObjectType = "PASPolicyOption"
		$this.PolicyOption = $po
		$this.fromPolicy   = $fp
		$this.PolicyValue  = $pv
	}
}# class PASPolicyOption
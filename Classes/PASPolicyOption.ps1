# class to hold Policy Options
[NoRunspaceAffinity()]
class PASPolicyOption
{
	[System.String]$PolicyOption
	[System.String]$fromPolicy
	[PSObject]$PolicyValue

	# constructor for reserialization
    PASPolicyOption ($pasobject)
    {
        # for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# PASPolicyOption ($pasobject) 

	PASPolicyOption([System.String]$po, [System.String]$fp, [PSObject]$pv) 
	{
		$this.PolicyOption = $po
		$this.fromPolicy   = $fp
		$this.PolicyValue  = $pv
	}
}# class PASPolicyOption
# class to hold PasswordProfiles
class PASPasswordProfile
{
    [System.String]$Name
    [System.String]$ID
	[System.String]$Description
	[System.String]$SpecialCharSet
	[System.String]$FirstCharacterType
	[System.Boolean]$ConsecutiveCharRepeatAllowed
	[System.Boolean]$AtLeastOneSpecial
	[System.Boolean]$AtLeastOneDigit
	[System.Int32]$MinimumPasswordLength
	[System.Int32]$MaximumPasswordLength
	[System.String]$ProfileType

	# empty constructor
	PASPasswordProfile () {}

	# constructor for reserialization
	PASPasswordProfile ($pasobject)
	{
		# for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# PASPasswordProfile ($pasobject)
}# class PASPasswordProfile

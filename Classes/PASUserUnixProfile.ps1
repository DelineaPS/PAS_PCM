# class for User UNIX profile information
[NoRunspaceAffinity()]
class PASUserUnixProfile
{
	[System.String]$User
	[System.String]$UserUuid
	[System.String]$UnixName
	[System.String]$Uid
	[System.String]$Gid
	[System.String]$UPN
	[System.String]$HomeDirectory
	[System.String]$Shell
	[System.String]$Gecos
	hidden [System.String]$PASPCMObjectType

	# empty constructor
    PASUserUnixProfile () {}

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
    PASUserUnixProfile($unixprofile)
    {
		$this.PASPCMObjectType = "PASUserUnixProfile"

		$this.User          = $unixprofile.UPN
		$this.UserUuid      = $unixprofile.Uuid
		$this.UnixName      = $unixprofile.UnixName
		$this.Uid           = $unixprofile.Uid
		$this.Gid           = $unixprofile.Gid
		$this.UPN           = $unixprofile.UPN
		$this.HomeDirectory = $unixprofile.Home
		$this.Shell         = $unixprofile.Shell
		$this.Gecos         = $unixprofile.Gecos
    }# PASUserUnixProfile($unixprofile)
}# class PASUserUnixProfile
#[NoRunspaceAffinity()] # uncomment this for PowerShell 7.4 or greater.
class PublicClass
{
	[System.String]$Name

	CustomClass () {}

	CustomClass ([System.String]$n)
	{
		$this.Name = $n
	}
}# class PublicClass
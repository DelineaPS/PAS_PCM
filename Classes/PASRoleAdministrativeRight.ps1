# class to hold PAS Role Administrative Rights
[NoRunspaceAffinity()]
class PASRoleAdministrativeRight
{
    [System.String]$Description
    [System.String]$Path

    # empty constructor
    PASRoleAdministrativeRight () {}

	# primary constructor
    PASRoleAdministrativeRight([System.String]$d, [System.String]$p)
    {
        $this.Description = $d
        $this.Path        = $p
    }
}# class PASRoleAdministrativeRight
# class to hold SearchPrincipals
[NoRunspaceAffinity()]
class PASPrincipal
{
    [System.String]$Name
    [System.String]$ID

    PASPrincipal($n,$i)
    {
        $this.Name = $n
        $this.ID = $i
    }
}# class PASPrincipal

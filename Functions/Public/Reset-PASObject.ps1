###########
#region ### global:Reset-PASObject # CMDLETDESCRIPTION : Rebuilds a PAS_PCM type object from XML/JSON data :
###########
function global:Reset-PASObject
{
    <#
    .SYNOPSIS
    Rebuilds a PAS_PCM type object from XML/JSON data.

    .DESCRIPTION
	This cmdlet will rebuild a PAS_PCM object from an xml or Json source. Typically this would be used when it is needed
	to store special PAS_PCM class objects offline (either via Export-Clixml or ConvertTo-Json) and store the info locally
	to use at a later time.

	When you reimport this information into PowerShell (via Import-Clixml or ConvertFrom-Json), this information becomes
	"deserialized" and all the custom methods that were part of the original PAS_PCM objects are lost. Methods are not stored
	as part of the Export/ConvertTo process, only member properties are saved.

	To address this, each major PAS_PCM object has a .resetObject() method that will take imported xml/json data and 
	recreate the PAS_PCM object with methods. This isn't a complete rebuild, as certain nested properties will still not 
	count as their original version. However this can save a lot of time to get data back into the PowerShell session
	without having to do an entire new Get process.

    .PARAMETER Data
	The XML or JSON data to reimport. The type of object is determined by a special, hidden PASPCMObjectType property.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs the partially rebuilt PAS_PCM objects.

    .EXAMPLE
    C:\PS> $Accounts = Reset-PASObject -Data (Import-CliXml accounts.xml)
    Import the accounts.xml as XML, and use that as the data source for rebuilding the PASAccount objects and
	save it to $Accounts.

    .EXAMPLE
    C:\PS> $Sets = Reset-PASObject -Data $JsonDataSets
    Use the json data for rebuilding the PASSet objects and save it to $Sets.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The offline data to reserialize.", ParameterSetName = "Data")]
		[PSObject]$Data
    )

	$NewPASObjects = $Data | ForEach-Object -Parallel {

		# for each script in our PAS_PCMScriptBlocks
		foreach ($script in $using:PAS_PCMScriptBlocks)
		{
			# add it to this thread as a script, this makes all classes and functions available to this thread
			. $script.ScriptBlock
		}

		$obj = New-Object $_.PASPCMObjectType

		$obj.resetObject($_)

		$obj
	}| # $NewPASObjects = $Data | ForEach-Object -Parallel {
	ForEach-Object -Begin { $i = 0 } -Process { 
		
		$Completed = $($i/($Data | Measure-Object | Select-Object -ExpandProperty Count)*100)
		# incrementing result count
		$i++
		# update progress bar
		Write-Progress -Activity "Resetting Objects" -Status ("{0} out of {1} Complete" -f $i,$NewPASObjects.Count) -PercentComplete $Completed
		# returning the result
		$_
	} 
	return $NewPASObjects
}# function global:Reset-PASObject
#endregion
###########
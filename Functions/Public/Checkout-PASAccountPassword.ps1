###########
#region ### global:Checkout-PASAccountPassword # Checks out passwords for PASAccount objects
###########
function global:Checkout-PASAccountPassword
{
    <#
    .SYNOPSIS
    Checks out the password to a PASAccount object.

    .DESCRIPTION
	Performs a Checkout Password action on the provided PASAccount object. The password will be stored in
	the Password field of the PASAccount object if successful.

    .PARAMETER Accounts
	The PASAccount objects to checkout the password. Will only accept PASAccount type objects.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object that provides the account target 
	and the results of the checkout attempt.

    .EXAMPLE
    C:\PS> Checkout-PASAccountPassword -Accounts $PASAccounts
	For the provided PASAccount objects, checkout out the password and store it in the Password field.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Accounts to checkout", ParameterSetName = "Account")]
		[PASAccount[]]$Accounts
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# multithreaded checkout on each account object
	$AllData = $Accounts | ForEach-Object -Parallel {

		# aliasing and reasserting connection and script information
		$account = $_
		$PASConnection         = $using:PASConnection
		$PASSessionInformation = $using:PASSessionInformation

		# for each script in our PAS_PCMScriptBlocks
		foreach ($script in $using:PAS_PCMScriptBlocks)
		{
			# add it to this thread as a script, this makes all classes and functions available to this thread
			. $script.ScriptBlock
		}

		$obj = New-Object PSObject

		$obj | Add-Member -MemberType NoteProperty -Name Account -Value $account.SSName

		Try
		{
			$result = $account.CheckoutPassword()

			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $result
		}
		Catch
		{
			# if an error occurred during checkout, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during CheckoutPassword on PASAccount object.")
			$e.AddExceptionData($_)
			$e.AddData("result",$result)
			$e.AddData("account",$account)
			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $e
		}# Catch
		Finally
		{
			# nulling values to free memory
			$result = $null
			$account = $null
		}

		# return the returner object
		$obj
		
	} |# $Accounts | ForEach-Object -Parallel {
	ForEach-Object -Begin { $i = 0 } -Process { 
			
		$Completed = $($i/($Accounts | Measure-Object | Select-Object -ExpandProperty Count)*100)
		# incrementing result count
		$i++
		# update progress bar
		Write-Progress -Activity "Checking out passwords" -Status ("{0} out of {1} Complete" -f $i,$Accounts.Count) -PercentComplete $Completed
		# returning the result
		$_
	}# | ForEach-Object -Begin { $i = 0 } -Process {

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData
}# function global:Checkout-PASAccountPassword
#endregion
###########
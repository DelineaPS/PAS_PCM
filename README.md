# PAS_PCM (PAS PowerShell Cloud Module)

A variety of functions to make working with Delinea's Privileged Access Service (PAS) even easier.

There are two ways of working with the PAS_PCM; the "Cloud Grab" method and a traditional download locally and run method.

**This module requires PowerShell version 7.4+ or greater.**

## PAS_PCM (Cloud Grab)

To get started, copy the snippet below and paste it directly into a PowerShell (Run-As Administrator not needed) window and run it. This effectively invokes every script from this GitHub repo directly as a web request and dot sources it into your current PowerShell session.

One benefit of this method is when updates/fixes/enhancements are made to the repo, a new Cloud Grab will obtain those changes without needing to compile, deploy, and install a new PowerShell module. Effectively, this design makes this repo a "Cloud-based PowerShell Module".

```PowerShell
$PAS_PCM = ([ScriptBlock]::Create(((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DelineaPS/PAS_PCM/main/PAS_PCM.ps1').Content))); . $PAS_PCM
```

## PAS_PCM (Local Grab)

If you want to run all of this locally, download all the scripts in this repo to a local folder, and run the primary script with the following:

```PowerShell
. (([ScriptBlock]::Create((Get-Content .\PAS_PCM_local.ps1 -Raw))))
```

## Disclaimer

The contents (scripts, documentation, examples) included in this repository are not supported under any Delinea standard support program, agreement, or service. The code is provided AS IS without warranty of any kind. Delinea further disclaims all implied warranties, including, without limitation, any implied warranties of merchantability or fitness for a particular purpose. The entire risk arising out of the code and content's use or performance remains with you. In no event shall Delinea, its authors, or anyone else involved in the creation, production, or delivery of the content be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the code or content, even if Delinea has been advised of the possibility of such damages.

## How to use

After using the Cloud Grab or Local Grab, the cmdlets in the repo are available in the PowerShell session. The folder structure provided here is a suggestion, use whatever folder structure you wish for your project. Both the Cloud Grab and the Local Grab will simply search all folders recursively for any PowerShell scripts within them.

All functions have standard PowerShell help files associated with them. So you can use `Get-Help Connect-PASTenant` to get the help file for that cmdlet.

First you need to connect to your tenant with `Connect-PASTenant`. Here is an example:

```PowerShell
Connect-PASTenant -Url mytenant.my.centrify.net -User mycloudadmin@domain.com
```

*Federated Users* - a small popup will occur that will have you log into your Federated IdP. Once you complete authentication, the pop should close and you should be back in the PowerShell session.

*Non-Federated Users* - You will be prompted for a password and whatever MFA challenge is associated with that login.

### Underscore (_) scripts

Any `.ps1` that starts with an underscore (_) will be ignored by the module processing. This would be useful in the event you need to temporarily disable a script without removing it.

## Once Connected

If you get output from the `Connect-PASTenant` cmdlet, you're connected and will remain connected for however long your tenant allows you to stay connected. All further cmdlets using this module from this point forward will use your credentials as if you were logged into the GUI tenant.

Use `Get-PASPCMCommands` to display all cmdlets related to this module.

Some cmdlets have additional methods with the custom class objects they return. See the help file for each cmdlet for more details.

## How to update

As new scripts are added into whatever Folders you want, the next Cloud Grab should grab those changes.

$Logfilepath = "$env:HOMEDRIVE$env:HOMEPATH\Projekte\PSLife\GitMigration\svn-log-migration"

$Logfilename = "$(gc env:computername).log"

$Logfile = "$Logfilepath\$Logfilename"

function LogWrite {
    Param ([string]$logstring)
    Add-Content $Logfile -value $logstring
}

function CreateFileIfNotExists($path, $filename) {
    if (!(Test-Path "$path\$filename"))
    {
	New-Item -path $path -name $filename -type "file"
    }
}

function Get-AllRevisions([string]$LogfilePath=$Logfile,[string]$Url="https://scm.adesso.de/scm/svn/PSLife/core",[string]$StartRevision,[string]$EndRevision) {
    #CreateFileIfNotExists($Logfilepath, $Logfilename)
    #LogWrite "Searching for all revisions on $Url"
    if ([string]::IsNullOrEmpty($StartRevision)) {
	svn log $Url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
    } else {
	if ([string]::IsNullOrEmpty($EndRevision)) {
	    svn log -r "$StartRevision"  $Url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
	} else {
	    svn log -r $StartRevision':'$EndRevision  $Url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
	}
    }
}

function Get-SvnLogMessage($revision, $Url="https://scm.adesso.de/scm/svn/PSLife/core") {
    $SvnEncoding = [System.Text.Encoding]::GetEncoding("CP850")
    $completeLog = (svn log -r $revision https://scm.adesso.de/scm/svn/PSLife/core)
    $lineCount = $completeLog[1] -match "\d+ line" |
      %{ $matches[0].subString(0,$matches[0].indexOf(" line")) }
    $startIndex = 3
    $endIndex = $startIndex + $lineCount -1
    $comment = $completeLog[$startIndex..$endIndex]
    $realComment = [System.Text.Encoding]::Default.GetString( $SvnEncoding.GetBytes($comment -join "`r`n")) | Out-String
    $realComment
}

function Is-LogMessageToBeUpdated($LogMessage, $SearchPattern="Jira Ticket Nr.: (?!PSLCORE)") {
    #exWrite-Host $logMessage
    $LogMessage -match $SearchPattern
}

function Write-NewSvnLogMessage($OldLogMessage, $OldString="Jira Ticket Nr.: ", $NewString="Jira Ticket Nr.: PSLCORE-") {
    #Write-Host "OldString: $OldString NewString $NewString"
    $OldLogMessage.replace($OldString, $NewString)
}

function Get-SvnChangeLogCommand([string]$revision, [string]$url, [string]$newLogMessage) {
    "svn propset -r $revision --revprop svn:log ""$newLogMessage"" $url "
}

function Set-NewSvnLogMessage([string]$revision, [string]$Url, [string]$logfilepath, [string]$newLogMessage) {
    #Write-Host "Revision: $revision Log Messag: $newLogmessage, URL: $Url, Logfilepath: $logfilepath"
    #Write-Host "Executing command svn propset -r $revision --revprop svn:log $newLogMessage $Url "
    Add-Content $logfilepath -value "Executing command svn propset -r $revision --revprop svn:log $message $Url "
}

function Write-SvnAllCommentChanges($Url="https://scm.adesso.de/scm/svn/PSLife/core", $StartRevision, $EndRevision, $LogfilePath=$Logfile, $CommandOutputLog, [bool]$ExecuteFlag) {
    #Write-Host "Url $Url Logfile $LogfilePath StartRevision $StartRevision endRev  $EndRevision"
    #$revisions = Get-AllRevisions -Url $Url -StartRevision $StartRevision -EndRevision $EndRevision
    #foreach($rev in $revisions) {
	#Write-Host "Teste Revision $rev"
#	$oldLogMessage = Get-SvnLogMessage($rev)
#	if (Is-LogMessageToBeUpdated -LogMessage $oldLogMessage) {
	    #Write-Host "Revision $rev log wird geändert"
#	    $newLogMessage = Write-NewSvnLogMessage($oldLogMessage)
#	    Add-Content $LogfilePath -value "`nRevision: $rev `nOld Log message: $oldlogmessage`nNew Log message: $newLogMessage`n`n"
#	    $logChange = new-object psobject -Property @{
#		Revision = $rev
#		OldLogMessage = $oldLogMessage
#		NewLogMessage = $newLogMessage
#	    }
	    #Write-Host ($logChange | Format-Table Revision,OldLogMessage,NewLogMessage)
#	    Set-NewSvnLogMessage $rev $Url $LogfilePath $newLogMessage
#	}
 #   }

    $listOfChanges = Export-SvnCommentChanges -StartRevision $StartRevision -EndRevision $EndRevision -Url $Url -LogfilePath $LogfilePath -OutputFile $CommandOutputLog

    foreach($change in $listOfChanges) {
	$command = ($change | Select -ExpandProperty "SvnCommand")
	Add-Content $LogfilePath -value "Executing log change command: $command"
	if ($ExecuteFlag) {
	    #$revision = ($change | Select -ExpandProperty "Revision")
	    #$newLogMessage = ($change | Select -ExpandProperty "NewLogMessage")
	    iex "& $command"
	    #	iex "& svn propset -r $revision --revprop svn:log ""$newLogMessage"" $Url "
	}
    }
}

function Export-SvnCommentChanges($Url="https://scm.adesso.de/scm/svn/PSLife/core", $StartRevision, $EndRevision, $LogfilePath=$Logfile, $OutputFile, $SearchPattern="Jira Ticket Nr.: (?!PSLCORE)", $OldString="Jira Ticket Nr.: ", $NewString="Jira Ticket Nr.: PSLCORE-") {
    $revisions = Get-AllRevisions -Url $Url -StartRevision $StartRevision -EndRevision $EndRevision
    $listOfLogChanges = @()
    foreach($rev in $revisions) {
	#Write-Host "Teste Revision $rev"
	$oldLogMessage = Get-SvnLogMessage($rev)
	if (Is-LogMessageToBeUpdated -LogMessage $oldLogMessage -SearchPattern $SearchPattern) {
	    #Write-Host "Revision $rev log wird geändert"
	    $newLogMessage = Write-NewSvnLogMessage -OldLogMessage $oldLogMessage -SearchPattern $SearchPattern -OldString $OldString -NewString $NewString
	    $svnCommand = Get-SvnChangeLogCommand -revision $rev -url $Url -newLogMessage $newLogMessage
	    Add-Content $LogfilePath -value "`nGenerated Change for revision: $rev `nOld Log message: $oldLogMessage`nNew Log message: $newLogMessage`n`n"
	    # Write-Host "Revision $rev Old: $oldLogMessage New: $newLogMessage Command: $svnCommand"
	    $logChange = new-object psobject -Property @{
		Revision = $rev
		OldLogMessage = $oldLogMessage
		NewLogMessage = $newLogMessage
		SvnCommand = $svnCommand
	    }
	    $listOfLogChanges += $logChange
	}
    }
    if (![string]::IsNullOrEmpty($OutputFile)) {
	Export-Clixml -InputObject $listOfLogChanges -Path $OutputFile		
    }
    $listOfLogChanges
}


export-modulemember -function Write-SvnAllCommentChanges, Export-SvnCommentChanges

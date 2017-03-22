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

function Get-AllRevisions([string]$logfilePath=$Logfile,[string]$url="https://scm.adesso.de/scm/svn/PSLife/core",[string]$startRevision,[string]$endRevision) {
    #CreateFileIfNotExists($Logfilepath, $Logfilename)
    #LogWrite "Searching for all revisions on $url"
    if ([string]::IsNullOrEmpty($startRevision)) {
	svn log $url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
    } else {
	if ([string]::IsNullOrEmpty($endRevision)) {
	    svn log -r "$startRevision"  $url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
	} else {
	    svn log -r $startRevision':'$endRevision  $url | Select-String -Pattern "^r\d+.*" | %{ if ($_ -match '^r\d+') {$matches[0]}}
	}
    }
}

function Get-SvnLogMessage($revision, $url="https://scm.adesso.de/scm/svn/PSLife/core") {
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

function Is-LogMessageToBeUpdated($logMessage) {
    #exWrite-Host $logMessage
    $logMessage -match "Jira Ticket Nr.: (?!PSLCORE)"
}

function Write-NewSvnLogMessage($oldLogMessage) {
    $oldLogMessage.replace("Jira Ticket Nr.: ","Jira Ticket Nr.: PSLCORE-")
}

function Set-NewSvnLogMessage([string]$revision, [string]$url, [string]$logfilepath, [string]$newLogMessage) {
    Write-Host "Revision: $revision Log Messag: $newLogmessage, URL: $url, Logfilepath: $logfilepath"
    Write-Host "Executing command svn propset -r $revision --revprop svn:log $newLogMessage $url "
    Add-Content $logfilepath -value "Executing command svn propset -r $revision --revprop svn:log $message $url "
}

function Write-SvnAllCommentChanges($logfilePath=$Logfile, $url="https://scm.adesso.de/scm/svn/PSLife/core", $startRevision, $endRevision) {
    Write-Host "Url $url Logfile $logfilePath startRevision $startRevision endRev  $endRevision"
    $revisions = Get-AllRevisions -url $url -startRevision $startRevision -endRevision $endRevision
    foreach($rev in $revisions) {
	#Write-Host "Teste Revision $rev"
	$oldLogMessage = Get-SvnLogMessage($rev)
	if (Is-LogMessageToBeUpdated($oldLogMessage)) {
	    #Write-Host "Revision $rev log wird geändert"
	    $newLogMessage = Write-NewSvnLogMessage($oldLogMessage)
	    Add-Content $logfilePath -value "`nRevision: $rev `nOld Log message: $oldlogmessage`nNew Log message: $newLogMessage`n`n"
	    Set-NewSvnLogMessage $rev $url $logfilePath $newLogMessage
	}
    }
}

export-modulemember -function Write-SvnAllCommentChanges 

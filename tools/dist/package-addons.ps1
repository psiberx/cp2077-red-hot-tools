param ($ReleaseBin, $ProjectName = "RedHotTools")

#$StageDir = "build/package"
$DistDir = "build/dist"

#& $($PSScriptRoot + "\steps\compose-cet-mod.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName}
#& $($PSScriptRoot + "\steps\create-zip-from-stage.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -Suffix "CET" -DistDir ${DistDir}
#
#Remove-Item -Recurse ${StageDir}

& $($PSScriptRoot + "\steps\compile-vscode-ext.ps1") -DistDir ${DistDir}

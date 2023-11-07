param ($ReleaseBin, $ProjectName = "RedHotTools")

$StageDir = "build/package"
$DistDir = "build/dist"

& $($PSScriptRoot + "\steps\compose-plugin-red4ext.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -ReleaseBin ${ReleaseBin}
& $($PSScriptRoot + "\steps\compose-plugin-data.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName}
& $($PSScriptRoot + "\steps\create-zip-from-stage.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -Version Auto -DistDir ${DistDir}

Remove-Item -Recurse ${StageDir}

& $($PSScriptRoot + "\steps\compose-cet-mod.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName}
& $($PSScriptRoot + "\steps\create-zip-from-stage.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -Version Auto -Suffix "CET" -DistDir ${DistDir}

Remove-Item -Recurse ${StageDir}

param ($ReleaseBin, $ProjectName = "RedHotTools")

$StageDir = "build/package"
$DistDir = "build/dist"

& $($PSScriptRoot + "\steps\compose-plugin-red4ext.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -ReleaseBin ${ReleaseBin}
& $($PSScriptRoot + "\steps\create-zip-from-stage.ps1") -StageDir ${StageDir} -ProjectName ${ProjectName} -Version Auto -DistDir ${DistDir}

Remove-Item -Recurse ${StageDir}

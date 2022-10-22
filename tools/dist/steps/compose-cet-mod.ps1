param ($StageDir, $ProjectName)

$ModDir = "${StageDir}/bin/x64/plugins/cyber_engine_tweaks/mods/${ProjectName}"

New-Item -ItemType directory -Force -Path ${ModDir} | Out-Null
Copy-Item -Path "support/cet/*.lua" -Recurse -Force -Destination ${ModDir}

param ($StageDir, $ProjectName)

$ModsDir = "${StageDir}/bin/x64/plugins/cyber_engine_tweaks/mods"

New-Item -ItemType directory -Force -Path ${ModsDir} | Out-Null
Copy-Item -Path "support/cet/" -Filter "*.lua" -Destination ${ModsDir} -Recurse -Container
Rename-Item -path "${ModsDir}/cet" -NewName ${ProjectName}

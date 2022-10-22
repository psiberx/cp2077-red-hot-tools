param ($DistDir)

Set-Location -Path "support/vscode"

& .\node_modules\.bin\vsce package -o "../../${DistDir}"

Set-Location -Path "../.."

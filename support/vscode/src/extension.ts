import * as vscode from 'vscode'
import * as fs from 'fs'
import * as path from 'path'

const pluginPath = "red4ext/plugins/RedHotTools"
const pluginBin = "RedHotTools.dll"
const scriptsHot = ".hot-scripts"
const tweaksHot = ".hot-tweaks"

const scriptsExts = [".reds"]
const tweaksExts = [".yaml", ".tweak"]
const tweaksPath = "r6/tweaks"

function isScriptFile(filePath: string): boolean {
  return scriptsExts.includes(path.extname(filePath))
}

function isTweakFile(filePath: string): boolean {
  return tweaksExts.includes(path.extname(filePath))
}

function inTweaksDir(gameDir: string, filePath: string): boolean {
  const rel = path.relative(path.join(gameDir, tweaksPath), filePath)
  return rel != "" && !rel.startsWith('..') && !path.isAbsolute(rel)
}

function isScriptFileEditor(editor: vscode.TextEditor|undefined): boolean {
  return editor != undefined && isScriptFile(editor.document.fileName)
}

function isTweakFileEditor(gameDir: string, editor: vscode.TextEditor|undefined): boolean {
  return editor != undefined && isTweakFile(editor.document.fileName) && inTweaksDir(gameDir, editor.document.fileName)
}

function setContexts(gameDir: string, editor: vscode.TextEditor|undefined) {
  vscode.commands.executeCommand('setContext', 'redHotTools.resourceIsScript', isScriptFileEditor(editor))
  vscode.commands.executeCommand('setContext', 'redHotTools.resourceIsTweak', isTweakFileEditor(gameDir, editor))
}

export function activate(context: vscode.ExtensionContext) {
  const log = vscode.window.createOutputChannel("RedHotTools")
  const config = vscode.workspace.getConfiguration()
  const gameDir = String(config.get('redHotTools.gameDir') || config.get('redscript.gameDir'))

  if (!gameDir) {
    log.appendLine('Cyberpunk 2077 directory is not configured')
    log.dispose()
    return
  }

  if (!fs.existsSync(gameDir)) {
    log.appendLine('Cyberpunk 2077 directory doesn\'t exist')
    log.dispose()
    return
  }

  const pluginDir = path.join(gameDir, pluginPath)

  if (!fs.existsSync(path.join(pluginDir, pluginBin))) {
    log.appendLine('RedHotTools plugin is not installed')
    log.dispose()
    return
  }

  setContexts(gameDir, vscode.window.activeTextEditor)

  vscode.window.onDidChangeActiveTextEditor((editor: vscode.TextEditor|undefined) => {
    setContexts(gameDir, editor)
  })

  context.subscriptions.push(vscode.commands.registerCommand('redHotTools.reloadScripts', async () => {
    const editor = vscode.window.activeTextEditor
    if (editor != undefined) {
      try {
        await fs.promises.appendFile(path.join(pluginDir, scriptsHot), '')
      }
      catch (e) {
        log.appendLine('Failed to reload scripts')
      }
    }
  }))

  context.subscriptions.push(vscode.commands.registerCommand('redHotTools.reloadTweaks', async () => {
    const editor = vscode.window.activeTextEditor
    if (editor != undefined) {
      const tweaksDir = path.join(gameDir, tweaksPath)
      const relativePath = path.relative(tweaksDir, editor.document.fileName)
      const relativeDir = path.dirname(relativePath)
      const targetPath = relativeDir != "." ? relativeDir : relativePath
      try {
        await fs.promises.appendFile(path.join(pluginDir, tweaksHot), targetPath + "\n")
      }
      catch (e) {
        log.appendLine(`Failed to reload tweaks [${targetPath}]`)
      }
    }
  }))
}

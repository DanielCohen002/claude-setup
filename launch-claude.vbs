' Runs launch-claude.ps1 with no console window at all (avoids the brief flash
' you get from powershell.exe -WindowStyle Hidden).
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\launch-claude.ps1"""
CreateObject("WScript.Shell").Run cmd, 0, False

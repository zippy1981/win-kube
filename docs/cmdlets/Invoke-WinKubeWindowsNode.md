---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Invoke-WinKubeWindowsNode

## SYNOPSIS

Runs a PowerShell script block on the Windows node over SSH.

## SYNTAX

### ByProfile (Default)

```text
Invoke-WinKubeWindowsNode -ScriptBlock <scriptblock> [-ArgumentList <string[]>]
 [-ClusterProfile <string>]
```

### ByNode

```text
Invoke-WinKubeWindowsNode -ScriptBlock <scriptblock> -Node <WindowsNode> [-ArgumentList <string[]>]
```

## ALIASES

## DESCRIPTION

The node's SSH default shell is cmd.exe, so the script block is copied to the node as a .ps1 file and run with
Windows PowerShell there, with ErrorActionPreference set to Stop.
The file is removed afterwards.
Values are
passed with -ArgumentList and bound to the script block's param() block in order.
Output lines are returned.

## EXAMPLES

### EXAMPLE 1

Invoke-WinKubeWindowsNode -ScriptBlock { Get-Service -Name containerd, kubelet }

Shows the state of the container runtime and kubelet on the Windows node.

### EXAMPLE 2

Get-WinKubeWindowsNode | Invoke-WinKubeWindowsNode -ArgumentList 'C:\k' -ScriptBlock {
    param($Path)
    Get-ChildItem -Path $Path
}

Lists the kubelet folder on the node.

## PARAMETERS

### -ArgumentList

Values for the script block's parameters, in order.
They may not contain double quotes or the cmd.exe
metacharacters & | < > ^ %.

```yaml
Type: System.String[]
DefaultValue: '@()'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ClusterProfile

Looks the Windows node up in this cluster when -Node is not given.
Defaults to winkube.

```yaml
Type: System.String
DefaultValue: $script:DefaultClusterProfile
SupportsWildcards: false
Aliases:
- Profile
ParameterSets:
- Name: ByProfile
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Node

The node to run on, from Get-WinKubeWindowsNode.
Accepts pipeline input.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ByNode
  Position: Named
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ScriptBlock

The script to run on the node.
Variables from the calling session are not available; pass them as arguments.

```yaml
Type: System.Management.Automation.ScriptBlock
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.PSObject

## OUTPUTS

### System.String

## NOTES

## RELATED LINKS

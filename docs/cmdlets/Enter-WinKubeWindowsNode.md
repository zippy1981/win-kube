---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Enter-WinKubeWindowsNode

## SYNOPSIS

Opens an interactive SSH session to the Windows node.

## SYNTAX

### __AllParameterSets

```text
Enter-WinKubeWindowsNode [[-ClusterProfile] <string>]
```

## ALIASES

## DESCRIPTION

Connects as Administrator with minikube's key for the node.
The node's default shell is cmd.exe; type
powershell to switch.
Use Invoke-WinKubeWindowsNode for scripted commands.

## EXAMPLES

### EXAMPLE 1

Enter-WinKubeWindowsNode

Opens a shell on the winkube cluster's Windows node.

## PARAMETERS

### -ClusterProfile

The minikube profile.
Defaults to winkube.

```yaml
Type: System.String
DefaultValue: $script:DefaultClusterProfile
SupportsWildcards: false
Aliases:
- Profile
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
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

## OUTPUTS

### System.Void

## NOTES

## RELATED LINKS

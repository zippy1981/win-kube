---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Get-WinKubeWindowsNode

## SYNOPSIS

Gets the cluster's Windows Server node.

## SYNTAX

### __AllParameterSets

```text
Get-WinKubeWindowsNode [[-ClusterProfile] <string>]
```

## ALIASES

## DESCRIPTION

Reads the node labelled kubernetes.io/os=windows from Kubernetes and matches its InternalIP to a minikube machine,
whose name is needed for SSH keys and the Hyper-V VM.
The Windows Server release is derived from the
node.kubernetes.io/windows-build label (10.0.26100 is 2025, 10.0.20348 is 2022, 10.0.17763 is 2019).

## EXAMPLES

### EXAMPLE 1

Get-WinKubeWindowsNode

Returns the Windows node of the winkube cluster.

### EXAMPLE 2

Get-WinKubeWindowsNode -ClusterProfile 'demo' | Invoke-WinKubeWindowsNode -ScriptBlock { Get-Service containerd }

Runs a command on the Windows node of the demo cluster.

## PARAMETERS

### -ClusterProfile

The minikube profile, which is also the kubectl context.
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

### WinKube.WindowsNode

## NOTES

Output: An object with Name, IP, Build, Release, Machine and ClusterProfile properties.

## RELATED LINKS

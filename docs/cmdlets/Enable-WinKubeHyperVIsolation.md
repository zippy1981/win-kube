---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Enable-WinKubeHyperVIsolation

## SYNOPSIS

Enables Hyper-V isolated containers on the Windows node, so older (ltsc2022) images can run on it.

## SYNTAX

### __AllParameterSets

```text
Enable-WinKubeHyperVIsolation [[-ClusterProfile] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

Installs the Hyper-V role inside the Windows node, adds a runhcs-wcow-hypervisor containerd runtime handler
with SandboxIsolation = 1 next to the default process-isolation handler, and creates RuntimeClass
windows-hyperv.
If the role had to be installed, the node VM is power-cycled through Hyper-V (with dynamic
memory turned off) and the cmdlet waits for the node to be Ready again.
See ADR 0005.

The node VM must expose virtualization extensions, which minikube sets when -CpuCount is 2 or more.

## EXAMPLES

### EXAMPLE 1

Enable-WinKubeHyperVIsolation

Prepares the winkube cluster's Windows node for ltsc2022 images.

### EXAMPLE 2

Enable-WinKubeHyperVIsolation -WhatIf

Shows what would change without touching the node.

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

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

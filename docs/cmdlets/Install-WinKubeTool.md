---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Install-WinKubeTool

## SYNOPSIS

Installs kubectl, helm and the Windows-node minikube build into .tools/bin.

## SYNTAX

### __AllParameterSets

```text
Install-WinKubeTool [[-KubernetesVersion] <string>] [-Force] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

Downloads kubectl for -KubernetesVersion and the latest helm, then builds minikube from the pinned fork commit
(ADR 0003), downloading a portable Go toolchain if none new enough is on PATH.
Needs git.
Tools already present
are kept unless -Force is given.
Runs without elevation.

## EXAMPLES

### EXAMPLE 1

Install-WinKubeTool

Installs whatever is missing.

### EXAMPLE 2

Install-WinKubeTool -Force

Reinstalls kubectl and helm and rebuilds minikube.

## PARAMETERS

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

### -Force

Download and rebuild everything, even tools that are already present.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### -KubernetesVersion

The kubectl version to download.
Defaults to the cluster's default Kubernetes version.

```yaml
Type: System.String
DefaultValue: $script:DefaultKubernetesVersion
SupportsWildcards: false
Aliases: []
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

### WinKube.Tool

## NOTES

Output: One object per tool with Name and Path.

## RELATED LINKS

---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Install-WinKubePrerequisite

## SYNOPSIS

Runs the one-time, elevated prerequisites setup (UAC prompt).

## SYNTAX

### __AllParameterSets

```text
Install-WinKubePrerequisite [-Restart] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

Starts scripts/Install-WinKubePrereqs.ps1 under Windows PowerShell 5.1, which self-elevates and then enables
Hyper-V and Containers, installs the OSS dockerd into C:\docker, enables long paths, and adds the user to
Hyper-V Administrators and docker-users.
It is the only part of win-kube that elevates (ADR 0004).
Reboot if it
asks, then sign out and back in so the group memberships apply.

## EXAMPLES

### EXAMPLE 1

Install-WinKubePrerequisite

Runs the setup and reports whether a reboot or sign-out is needed.

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

### -Restart

Reboot automatically if enabling a Windows feature requires it.

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

---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Install-WinKubeChart

## SYNOPSIS

Installs or upgrades a Helm chart on the cluster's Windows node, side-loading its images first.

## SYNTAX

### __AllParameterSets

```text
Install-WinKubeChart [[-Chart] <string>] [[-Release] <string>] [[-Namespace] <string>]
 [[-WindowsVersion] <string>] [[-Set] <string[]>] [[-Image] <string[]>] [[-TimeoutMinutes] <int>]
 [[-ClusterProfile] <string>] [-SkipImageLoad] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

Imports the chart's images into the Windows node (see Import-WinKubeImage), then runs helm upgrade --install with
--wait and the windows.version and windows.nodeVersion values, which charts in this repo use to pick image tags
and Hyper-V isolation.
An image family older than the node (ltsc2022 on the ltsc2025 node) needs
Enable-WinKubeHyperVIsolation first.

The default chart is the WordPress sample in charts/wordpress-windows, whose images default to
windows-nano-php and mysql-spike.
Its admin password is returned as a credential.

## EXAMPLES

### EXAMPLE 1

Install-WinKubeChart

Installs the WordPress sample with ltsc2025 images and returns its URL and admin credential.

### EXAMPLE 2

Install-WinKubeChart -WindowsVersion 2022 -Set 'install.title=Legacy'

Installs the sample with ltsc2022 images under Hyper-V isolation, with a custom site title.

## PARAMETERS

### -Chart

Path to the chart.
Defaults to charts/wordpress-windows.

```yaml
Type: System.String
DefaultValue: $script:DefaultChart
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
  Position: 7
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

### -Image

Images to side-load before installing.
Defaults to the sample's images when -Chart is the sample chart.

```yaml
Type: System.String[]
DefaultValue: '@()'
SupportsWildcards: false
Aliases:
- Images
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Namespace

The namespace to install into; created if missing.

```yaml
Type: System.String
DefaultValue: wordpress
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Release

The Helm release name.

```yaml
Type: System.String
DefaultValue: wp
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Set

Extra helm --set values, such as 'wordpress.service.nodePort=30080'.

```yaml
Type: System.String[]
DefaultValue: '@()'
SupportsWildcards: false
Aliases:
- HelmSet
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipImageLoad

Don't side-load images.

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

### -TimeoutMinutes

helm --timeout, which also bounds post-install hooks.
Windows image pulls and first starts are slow.

```yaml
Type: System.Int32
DefaultValue: 30
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
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

### -WindowsVersion

The image family to deploy: 2025 or 2022.

```yaml
Type: System.String
DefaultValue: 2025
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
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

### WinKube.ChartRelease

## NOTES

Output: Release, Namespace, Chart, Url and, for the sample, Credential.

## RELATED LINKS

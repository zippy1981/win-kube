---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# New-WinKubeCluster

## SYNOPSIS

Creates a win-kube cluster: a Linux control plane and a Windows Server 2025 worker on Hyper-V.

## SYNTAX

### __AllParameterSets

```text
New-WinKubeCluster [[-ClusterProfile] <string>] [[-KubernetesVersion] <string>] [[-CpuCount] <int>]
 [[-MemoryMB] <int>] [[-Isolation] <string>] [[-WindowsVhdUrl] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

Runs the Windows-node minikube build with --driver=hyperv, one control-plane node and one Windows worker, waits
for both nodes to be Ready, and labels them the way AKS does (agentpool, kubernetes.azure.com/mode and os-sku).
With -Isolation hyperv the VMs get static memory and the Windows node is set up for Hyper-V isolated containers,
so ltsc2022 images can run on it (ADR 0005).

Runs without elevation for members of Hyper-V Administrators (ADR 0004).
The first run downloads the Windows
VHDX; allow 20 minutes or more.

## EXAMPLES

### EXAMPLE 1

New-WinKubeCluster

Creates the default winkube cluster with process isolation.

### EXAMPLE 2

New-WinKubeCluster -Isolation hyperv -MemoryMB 8192 -InformationAction Continue

Creates a cluster that can also run ltsc2022 images, with 8 GB per node, showing progress.

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

### -CpuCount

Virtual CPUs for each node VM.
Nested virtualization, needed for Hyper-V isolation, requires at least 2.

```yaml
Type: System.Int32
DefaultValue: 4
SupportsWildcards: false
Aliases:
- Cpus
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

### -Isolation

'process' (default) runs only images that match the node build.
'hyperv' also enables Hyper-V isolation.

```yaml
Type: System.String
DefaultValue: process
SupportsWildcards: false
Aliases: []
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

### -KubernetesVersion

The control-plane version.
Must not be older than the kubelet in the Windows VHD (v1.37.0 by default).

```yaml
Type: System.String
DefaultValue: $script:DefaultKubernetesVersion
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

### -MemoryMB

Memory for each node VM, in MB.

```yaml
Type: System.Int32
DefaultValue: 6144
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

### -WindowsVhdUrl

A custom Windows node VHDX: a URL, an absolute path, or a file:// URI.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### WinKube.Cluster

## NOTES

Output: The state of the new cluster, as returned by Get-WinKubeCluster.

## RELATED LINKS

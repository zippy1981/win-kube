---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Get-WinKubeCluster

## SYNOPSIS

Gets the state of a win-kube cluster: minikube status, nodes, runtime classes and Helm releases.

## SYNTAX

### __AllParameterSets

```text
Get-WinKubeCluster [[-ClusterProfile] <string>]
```

## ALIASES

## DESCRIPTION

Returns one object describing the cluster.
Node entries include the AKS-style labels added by
New-WinKubeCluster.
If the cluster is not running, the Nodes, RuntimeClass and Release properties are empty.

## EXAMPLES

### EXAMPLE 1

Get-WinKubeCluster

Shows the winkube cluster.

### EXAMPLE 2

(Get-WinKubeCluster).Nodes | Format-Table -Property Name, OS, Ready, OsSku

Lists the nodes and whether they are Ready.

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

### WinKube.Cluster

## NOTES

Output: An object with ClusterProfile, Status, Nodes, RuntimeClass and Release properties.

## RELATED LINKS

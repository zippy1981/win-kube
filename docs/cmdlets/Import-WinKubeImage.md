---
document type: cmdlet
external help file: WinKube-Help.xml
HelpUri: ''
Locale: en-US
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# Import-WinKubeImage

## SYNOPSIS

Copies images from the local Docker engine into the Windows node's containerd.

## SYNTAX

### __AllParameterSets

```text
Import-WinKubeImage [[-Image] <string[]>] [[-WindowsVersion] <string>] [[-ClusterProfile] <string>]
 [-Force] [-WhatIf] [-Confirm]
```

## ALIASES

## DESCRIPTION

For each image: docker save to a tarball in .cache/images (reused while the image ID is unchanged), scp it to
the Windows node, and ctr images import it into the k8s.io namespace with --platform windows/amd64, so images
for an older Windows build are kept too.
A marker on the node records the imported image ID, so an unchanged
image is skipped unless -Force is given.
This avoids running a registry for images that exist only locally.

## EXAMPLES

### EXAMPLE 1

Import-WinKubeImage

Imports windows-nano-php:2025 and mysql-spike:2025.

### EXAMPLE 2

'myapp:2025', 'myworker:2025' | Import-WinKubeImage -Force

Imports two of your own images, even if they were imported before.

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
  Position: 2
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

### -Force

Import even when the node already has the same image ID.

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

### -Image

Image references in the local Docker engine.
Accepts pipeline input.
Defaults to the sample chart's images
for -WindowsVersion: windows-nano-php and mysql-spike.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Images
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
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

The tag used for the default images.
2025 or 2022.

```yaml
Type: System.String
DefaultValue: 2025
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

## OUTPUTS

### WinKube.ImportedImage

## NOTES

Output: One object per image, with Image, ImageId, Node and Status (Imported or AlreadyPresent).

## RELATED LINKS

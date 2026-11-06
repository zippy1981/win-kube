---
document type: module
Help Version: 1.0.0.0
HelpInfoUri:
Locale: en-US
Module Guid: 0772bf45-c0b4-4648-a306-cdd8b72c89bb
Module Name: WinKube
PlatyPS schema version: 2024-05-01
---

# WinKube Module

## Description

AKS-shaped local Kubernetes with a Windows Server container node, minikube-style.

## WinKube

### [Enable-WinKubeHyperVIsolation](Enable-WinKubeHyperVIsolation.md)

Enables Hyper-V isolated containers on the Windows node, so older (ltsc2022) images can run on it.

### [Enter-WinKubeWindowsNode](Enter-WinKubeWindowsNode.md)

Opens an interactive SSH session to the Windows node.

### [Get-WinKubeCluster](Get-WinKubeCluster.md)

Gets the state of a win-kube cluster: minikube status, nodes, runtime classes and Helm releases.

### [Get-WinKubeWindowsNode](Get-WinKubeWindowsNode.md)

Gets the cluster's Windows Server node.

### [Import-WinKubeImage](Import-WinKubeImage.md)

Copies images from the local Docker engine into the Windows node's containerd.

### [Install-WinKubeChart](Install-WinKubeChart.md)

Installs or upgrades a Helm chart on the cluster's Windows node, side-loading its images first.

### [Install-WinKubePrerequisite](Install-WinKubePrerequisite.md)

Runs the one-time, elevated prerequisites setup (UAC prompt).

### [Install-WinKubeTool](Install-WinKubeTool.md)

Installs kubectl, helm and the Windows-node minikube build into .tools/bin.

### [Invoke-WinKubeWindowsNode](Invoke-WinKubeWindowsNode.md)

Runs a PowerShell script block on the Windows node over SSH.

### [New-WinKubeCluster](New-WinKubeCluster.md)

Creates a win-kube cluster: a Linux control plane and a Windows Server 2025 worker on Hyper-V.

### [Remove-WinKubeCluster](Remove-WinKubeCluster.md)

Deletes a win-kube cluster and its VMs.

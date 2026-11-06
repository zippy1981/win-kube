@{
    RootModule           = 'WinKube.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '0772bf45-c0b4-4648-a306-cdd8b72c89bb'
    Author               = 'Justin Dearing'
    CompanyName          = 'Justin Dearing'
    Copyright            = '(c) Justin Dearing. All rights reserved.'
    Description          = 'AKS-shaped local Kubernetes with a Windows Server container node, minikube-style.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Enable-WinKubeHyperVIsolation'
        'Enter-WinKubeWindowsNode'
        'Get-WinKubeCluster'
        'Get-WinKubeWindowsNode'
        'Import-WinKubeImage'
        'Install-WinKubeChart'
        'Install-WinKubePrerequisite'
        'Install-WinKubeTool'
        'Invoke-WinKubeWindowsNode'
        'New-WinKubeCluster'
        'Remove-WinKubeCluster'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('Kubernetes', 'minikube', 'AKS', 'Windows', 'Containers', 'Hyper-V', 'Helm')
            ProjectUri = 'https://github.com/zippy1981/win-kube'
        }
    }
}

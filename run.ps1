[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $PR = $false,

    [Parameter()]
    [string]
    $prId = [string]::Empty,

    [Parameter()]
    [string]
    $prBaseBranch = [string]::Empty,

    [Parameter()]
    [switch]
    $AnalysisDebugLog = $false
)

class AnalysisParameter {
    [string]$AnalysisType
    [string]$Value

    AnalysisParameter([string]$aType, [string]$val) {
        $this.AnalysisType = $aType
        $this.Value = $val
    }
}

# Powershell Config
$ErrorActionPreference = "Stop"

###
### Constants
###
$SONARQUBE_URL = [Environment]::GetEnvironmentVariable("SONARQUBE_URL")
$SONARQUBE_TOKEN = [Environment]::GetEnvironmentVariable("SONARQUBE_TOKEN")

$PROJECT_NAME = "SonarQubeGHASTest"
$PROJECT_KEY = "lukas-frystak-sonarsource_SonarQubeGHASTest_AYPly4BPCUOcPj9BCQiF"
$PROJECT_VERSION = "1.0.0"
$SOLUTION = "./src/SonarQubeGHASTest.sln"
$coverageReportDirectory = ".\TestResults"
$coverageReportPath = "$coverageReportDirectory\dotCover.Output.html"
$testReportPath = ".\**\*.trx"
$mainBranchName = "main"
$branchName = git rev-parse --abbrev-ref HEAD

###
### Process flags and parameters
###
$BR = $false

if ($PR) {
    [boolean]$doExit = $false

    if ($prId -eq [string]::Empty) {
        Write-Warning "Provide pull request ID with the '-prId' parameter"
        $doExit = $true
    }
    if ($prBaseBranch -eq [string]::Empty) {
        Write-Warning "Provide pull request target (base) branch with the '-prBaseBranch' parameter"
        $doExit = $true
    }
    if ($doExit) {
        Exit 1
    }
}
else {
    if ($mainBranchName -ne $branchName) {
        Write-Host "Running branch analysis"
        $BR = $true
    }
}

if ($AnalysisDebugLog) {
    $AnalysisDebugLogString = "true"
}
else {
    $AnalysisDebugLogString = "false"
}

# .NET Analysis parameters
$dotnetScannerParameterList = @(
    [AnalysisParameter]::new("--", "/key:$PROJECT_KEY")
    [AnalysisParameter]::new("--", "/name:$PROJECT_NAME")
    [AnalysisParameter]::new("--", "/v:$PROJECT_VERSION")
    [AnalysisParameter]::new("--", "/d:sonar.host.url=$SONARQUBE_URL")
    [AnalysisParameter]::new("--", "/d:sonar.login=$SONARQUBE_TOKEN")
    [AnalysisParameter]::new("--", "/d:sonar.cs.dotcover.reportsPaths=$coverageReportPath")
    [AnalysisParameter]::new("--", "/d:sonar.cs.vstest.reportsPaths=$testReportPath")
    [AnalysisParameter]::new("--", "/d:sonar.verbose=$AnalysisDebugLogString")
    [AnalysisParameter]::new("BR", "/d:sonar.branch.name=$branchName")
    [AnalysisParameter]::new("PR", "/d:sonar.pullrequest.key=$prId")
    [AnalysisParameter]::new("PR", "/d:sonar.pullrequest.base=$prBaseBranch")
    [AnalysisParameter]::new("PR", "/d:sonar.pullrequest.branch=$branchName")
)

# Filter the analysis parameters
if ($PR) {
    # Exclude only parameters related to Branch analysis
    $dotnetScannerParameterList = $dotnetScannerParameterList | Where-Object { $_.AnalysisType -ne "BR" }
}
else {
    if ($BR) {
        # Exclude only parameters related to Pull Request analysis
        $dotnetScannerParameterList = $dotnetScannerParameterList | Where-Object { $_.AnalysisType -ne "PR" }
    }
    else {
        # Exclude parameters related to branch analysis and pull request analysis
        # I.e., use only the generic parameters
        $dotnetScannerParameterList = $dotnetScannerParameterList | Where-Object { $_.AnalysisType -eq "--" }
    }
}

###
### Build and analyze the projects
###

# Prepare .NET analysis
$dotnetScannerParameters = [string]::Join(' ', $($dotnetScannerParameterList).Value)
$beginCmd = "dotnet sonarscanner begin $dotnetScannerParameters"
Invoke-Expression $beginCmd

# .NET build and test
dotnet build $SOLUTION --configuration Release
#dotnet dotcover test $SOLUTION --no-build --configuration Release --dcReportType=html --dcOutput=$coverageReportPath --logger trx


# Run .NET analysis
dotnet sonarscanner end /d:sonar.login=$SONARQUBE_TOKEN 3>&1 2>&1 > dotnet-analysis.log
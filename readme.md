# SonarQube sonar-ps-plugin Integration
Extent sonar-ps-plugin Integration to show Test Cases and Code Coverage in SonarQube

I really like the [sonar-ps-plugin](https://github.com/gretard/sonar-ps-plugin). But out of the box it misses:
1. Custom rules for PSScriptAnalyzer
2. Pester tests
3. Code coverage

I extended the solution to to integrate all three aspects.


# 1. Using Custom Rules for PSScriptAnalyzer
There are three requirements to integrate custom rules
1. Environment variable must be set to make the path to the custom rules available to the scriptAnalyzer.ps1 file
2. Rules definitions for the custom rules must be intergated in sonar-ps-plugin solution
3. scriptAnalyzer.ps1 must be modified to call PSScriptAnalyzer with custom modules


## 1.1 Environment Variable
The modified scriptAnalyzer.ps1 script expects``$env:PSScriptAnalyzerCustomRulePath`` varaible.
The value must point to a directory where the custom rules are located on the local PC like so
```
C:\DEV\PSScriptAnalyzer\CustomRules
```
If the variable doesn't exists, the hole process defaults to the original behavior.


## 1.2 Integrate custom rules definitions in sonar-ps-plugin solution
To make sonar-ps-plugin aware of custom rules during the code evaluation in SonarQube the custom rules must be included in ``powershell-profile.xml`` and ``powershell-rules.xml`` files.
The first step to do so is to modify ``regenerateRulesDefinition.ps1``.
1. In 'regenerateRulesDefinition.ps1' look for the following line
```powershell
$powershellRules = Get-ScriptAnalyzerRule
```
2. Right after that line add the following line to add custom rules to the rules collection recognized by the plugin
```powershell
$powershellRules += Get-ScriptAnalyzerRule -CustomRulePath $env:PSScriptAnalyzerCustomRulePath
```
**NOTE:**
Every function exposed by a custom rule module ``MUST HAVE`` a .SYNOPSIS and within the .SYNOPSIS it ``MUST HAVE`` .DESCRIPTION

I modified the 'regenerateRulesDefinition.ps1' further to make this condition a blocker in the process like so:
```powershell
if([string]::IsNullOrEmpty($rule.Description))
{
    throw "Every Rule needs a Description. Otherwise Sonarqube fails to start using this plugin: $($rule.RuleName)"
}
```



## 1.3 Modify scriptAnalyzer.ps1 to call PSScriptAnalyzer with custom modules
The following extract from my modified script shows how the parameters for PSScriptAnalyzer are crafted depending on the existence of the environment variable.

```powershell

if(($null -ne $env:PSScriptAnalyzerCustomRulePath) -and
    (-not [string]::IsNullOrEmpty($env:PSScriptAnalyzerCustomRulePath)) -and
    (Test-Path $env:PSScriptAnalyzerCustomRulePath.ToString())
)
{
    $customRulesPath = "{0}\*.psm1" -f $env:PSScriptAnalyzerCustomRulePath
    $msg = "Calling ScriptAnalyzer with custom rules: {0}" -f $customRulesPath

    get-scriptAnalyzerRule -CustomRulePath ($customRulesPath) | Select-Object -ExpandProperty RuleName | Out-Host

    $settings.Add("CustomRulePath", @($customRulesPath))
    $settings.Add("RecurseCustomRulePath", $true)

    "Parameters for ScriptAnalyzer:" | Out-Host
    $settings | Out-Host
}
(Invoke-ScriptAnalyzer -Path "$inputDir" -Settings $settings | Select-Object RuleName, Message, Line, Column, Severity, @{Name='File';Expression={$_.Extent.File }} | ConvertTo-Xml).Save("$output")

```

After these steps SonarQube respects PSScriptAnalyzer results including custom rules.


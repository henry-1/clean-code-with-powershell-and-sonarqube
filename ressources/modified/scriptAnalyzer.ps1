
param(
[string]$inputDir,
[string]$output
)

Import-Module PSScriptAnalyzer

$settings = @{
    IncludeDefaultRules = $true
}

#region added
if(($null -ne $env:PSScriptAnalyzerCustomRulePath) -and
    (-not [string]::IsNullOrEmpty($env:PSScriptAnalyzerCustomRulePath)) -and
    (Test-Path $env:PSScriptAnalyzerCustomRulePath.ToString())
)
{
    $customRulesPath = "{0}\*.psm1" -f $env:PSScriptAnalyzerCustomRulePath
    $msg = "Calling ScriptAnalyzer with custom rules: {0}" -f $customRulesPath
    write-host $msg -ForegroundColor Yellow
    get-scriptAnalyzerRule -CustomRulePath ($customRulesPath) | Select-Object -ExpandProperty RuleName | Out-Host

    $settings.Add("CustomRulePath", @($customRulesPath))
    $settings.Add("RecurseCustomRulePath", $true)

    "Parameters for ScriptAnalyzer:" | Out-Host
    $settings | Out-Host
}

#endregion added

(Invoke-ScriptAnalyzer -Path "$inputDir" -Settings $settings | Select-Object RuleName, Message, Line, Column, Severity, @{Name='File';Expression={$_.Extent.File }} | ConvertTo-Xml).Save("$output")
write-host "Finished ScriptAnalyzer" -ForegroundColor Green

# cut here if you only want to use PSScriptAnalyzer but do not want to integrate Pester

#region pester

#region functions for pester analysis
function Test-PesterRequirements {
    <#
        .SYNOPSIS
            Test if requirements are fullfilled to run Pester
        .NOTES
            Test if Pester module is installed and artefacts and modules folder exists
        .PARAMETER InputDir
            Project folder where subfolders must exist
    #>
    param(
        [string]$InputDir
    )
    $artefactsFolder = Join-Path $inputDir -ChildPath "artefacts"
    $modulesFolder = Join-Path $inputDir -ChildPath "modules"

    if($null -eq (Get-Module -listAvailable | Where-Object {$_.Name -eq "Pester"} ))
    {
        $msg = "Pester module missing."
        Write-Host $msg -ForegroundColor Red
        return $false
    }

    if(-not (Test-Path $artefactsFolder))
    {
        $msg = "'artefacts' folder missing. Analyzing process finished."
        Write-Host $msg -ForegroundColor Green
        exit
    }
    if(-not (Test-Path $modulesFolder))
    {
        $msg = "'modules' folder missing. Analyzing process finished."
        Write-Host $msg -ForegroundColor Green
        exit
    }

    return $true
}


function Open-XmlWriter
{
    <#
        .SYNOPSIS
            Starting a XML file
        .PARAMETER Path
            Path for the file to create
    #>
    [cmdletbinding()]
    [OutputType([System.XMl.XmlTextWriter])]
    param(
        [string]$Path
    )
    $xmlWriter = New-Object System.XMl.XmlTextWriter($Path, [System.Text.Encoding]::UTF8)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $xmlWriter.IndentChar = "`t"
    $xmlWriter
}

function Close-XmlWriter
{
    <#
        .SYNOPSIS
            Close a XML file
        .PARAMETER XmlWriter
            System.XMl.XmlTextWriter object to close

    #>
    [cmdletbinding()]
    [OutputType([System.Void])]
    param(
        [System.XMl.XmlTextWriter]$XmlWriter
    )
    $XmlWriter.Flush()
    $XmlWriter.Close()
}

function Get-Tests
{
    <#
        .SYNOPSIS
            Get Tests from Pester test results file 'testsuite' nodes
        .PARAMETER TestSuites
            List of 'testsuite' nodes from Pester test results file
    #>
    [cmdletbinding()]
    [OutputType([hashtable])]
    param(
        [array]$TestSuites
    )

    $testsInScript = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach($testSuite in $TestSuites)
    {
        $testCases = @($testSuite.Node.SelectNodes(".//testcase"))
        foreach($testCase in $testCases)
        {
            $functionName = $testCase.name.Split(".")[0]        # first part is 'Describe' from test
            $testName = $testCase.name.Split(".")[1]
            $testFilePath = $testCase.classname
            $testTime = $testCase.time

            $test = New-Object -TypeName PSCustomObject
            $test | Add-Member -MemberType NoteProperty -Name SUT -Value $functionName
            $test | Add-Member -MemberType NoteProperty -Name TestName -Value $testName
            $test | Add-Member -MemberType NoteProperty -Name FilePath -Value $testFilePath
            $test | Add-Member -MemberType NoteProperty -Name Duration -Value $testTime

            if($testCase.status -eq "Failed")
            {
                $errorMessage = ($testCase.ChildNodes | Select-Object -First 1).message
                $test | Add-Member -MemberType NoteProperty -Name Result -Value $testCase.status
                $test | Add-Member -MemberType NoteProperty -Name ErrorText -Value $errorMessage
            }

            if($testCase.status -eq "Passed")
            {
                $test | Add-Member -MemberType NoteProperty -Name Result -Value "success"
            }

            $testsInScript.Add($test)
        }
    }

    $testsInScript
}

function Get-ExecutionReport
{
    <#
        .SYNOPSIS
            Create a XML file file that can be used by SonarQube to analysie Test execution
        .PARAMETER xmlWriter
            System.XMl.XmlTextWriter object
        .PARAMETER Tests
            List of Test objects created by Get-Tests function
        .PARAMETER ScriptPath
            Root folder for the script, will be stripped from full path in the report
    #>
    [cmdletbinding()]
    [OutputType([System.Void])]
    param(
        [System.XMl.XmlTextWriter]$xmlWriter,
        [System.Collections.Generic.List[PSCustomObject]]$Tests,
        [string]$ScriptPath
    )

    $xmlWriter.WriteStartElement("testExecutions")           # <testExecutions version="1">
    $xmlWriter.WriteAttributeString("version","1")

    $testGroups = $tests | Group-Object Filepath
    $groupCount = $testGroups | Measure-Object | Select-Object -ExpandProperty Count

    for ($index_1 = 0; $index_1 -lt $groupCount; $index_1++) {
        $path = $testGroups[$index_1].Name.Replace($ScriptPath,"")
        $path = $path.Substring(1, $path.Length - 1).Replace("\","/")

        $xmlWriter.WriteStartElement("file")                     # <file path="Tests/Invoke-CommonFunctions.Tests.ps1">
        $xmlWriter.WriteAttributeString("path",$path)

        $grouping = $testGroups[$index_1].Group
        for($index_2 = 0; $index_2 -lt $grouping.Count; $index_2++)
        {
            # <testCase name="Find-OperationalDomainController" duration="3.8439"/>
            $xmlWriter.WriteStartElement("testCase")
            $xmlWriter.WriteAttributeString("name",$grouping[$index_2].TestName)
            $duration = [double]::Parse($grouping[$index_2].Duration, [cultureinfo]'en-us') * 10000
            $xmlWriter.WriteAttributeString("duration", $duration)
            if($grouping[$index_2].Result -ne "success")
            {
                $msgParts = $grouping[$index_2].ErrorText.Split("`n")
                $xmlWriter.WriteStartElement("error")
                $xmlWriter.WriteAttributeString("message",$msgParts[0].Trim())
                $xmlWriter.WriteString($grouping[$index_2].ErrorText)

                $xmlWriter.WriteEndElement()
            }

            $xmlWriter.WriteEndElement()
        }

        $xmlWriter.WriteEndElement()                          # </file>
    }
    $xmlWriter.WriteEndElement()                       # testExecutions
}

function Get-CodeCoverageReport
{
    <#
        .SYNOPSIS
            Create a XML file file that can be used by SonarQube to analysie Code coverage
        .PARAMETER Folders
            List of 'package' nodes from Pester test code coverage file
        .PARAMETER ScriptPath
            Root folder for the script, will be stripped from full path in the report
        .PARAMETER xmlWriter
            System.XMl.XmlTextWriter object
        .LINK
            https://docs.sonarsource.com/sonarqube/9.9/analyzing-source-code/test-coverage/generic-test-data/
    #>
    param(
        [array]$Folders,
        [string]$ScriptPath,
        [System.XMl.XmlTextWriter]$xmlWriter
    )
    $xmlWriter.WriteStartElement("coverage")
    $xmlWriter.WriteAttributeString("version","1")

    foreach($folder in $Folders)
    {
        $folderPath = $folder.node.name
        $files = $folder | Select-Xml -Xpath ".//sourcefile"
        foreach($file in $files){
            $path = "{0}/{1}" -f $folderPath, $file.node.name
            $ScriptPath = $ScriptPath.Replace("\","/")
            $path = $path.Replace($ScriptPath,"")
            $path = $path.Substring(1, $path.Length - 1 )

            $xmlWriter.WriteStartElement("file")
            $xmlWriter.WriteAttributeString("path",$path)

            $lines = $file | Select-Xml -XPath ".//line"
            foreach($line in $lines){
                $xmlWriter.WriteStartElement("lineToCover")
                $xmlWriter.WriteAttributeString("lineNumber",$line.node.nr)
                $covered = (0 -lt [int]$line.node.ci)
                $xmlWriter.WriteAttributeString("covered",$covered)
                $xmlWriter.WriteEndElement()                  # lineToCover
            }
            $xmlWriter.WriteEndElement()                      # </file>
        }
    }
    $xmlWriter.WriteEndElement()                              # </coverage>
}

# quit the analysis if requirements are not met
if(-not (Test-PesterRequirements -InputDir $inputDir))
{
    Write-Host "Analyzation process finished" -ForegroundColor Green
    exit
}

#endregion functions for pester analysis


Write-Host "Starting Pester" -ForegroundColor Yellow

# out files for pester analysis
$testReportFile = "artefacts/TestResults.xml"
$coverageReportFile = "artefacts/TestCoverage.xml"

# files with converted analysis results transfered to and used by SonarQube
$executionReport = "artefacts/executionReport.xml"
$coverageReport = "artefacts/coverageReport.xml"

# https://pester-docs.netlify.app/docs/commands/New-PesterConfiguration
$configuration = @{
    Run = @{
        PassThru = $false
        Path = 'tests/*'
        TestExtension = '.Tests.ps1'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = @('./*.ps*','modules/*.ps*')
        OutputPath = $coverageReportFile
        OutputFormat = 'CoverageGutters'       # JaCoCo, CoverageGutters
        OutputEncoding = 'UTF8'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = "JUnitXml"      #  NUnitXml, NUnit2.5, NUnit3 or JUnitXml
        OutputPath = $testReportFile
        OutputEncoding = 'UTF8'
        TestSuiteName = 'Pester'
    }
    Output = @{
        Verbosity = 'Normal'           # Detailed, Normal, Filtered, Auto, Error
    }
}
$config = New-PesterConfiguration -Hashtable $configuration
Invoke-Pester -Configuration $config

Write-Host "Finished Pester" -ForegroundColor Green
#endregion pester

#region codecoverage

Write-Host "Starting CodeCoverage" -ForegroundColor Yellow

$testResults = [xml] (Get-Content -Path $testReportFile)
$testSuites = $testResults | Select-Xml -Xpath "//testsuite"
$tests = Get-Tests -TestSuites $testSuites

$xmlWriter = Open-XmlWriter -Path $executionReport
Get-ExecutionReport -xmlWriter $xmlWriter -Test $tests -ScriptPath $inputDir
Close-XmlWriter -XmlWriter $xmlWriter

$coverageResults = [xml] (Get-Content -Path $coverageReportFile)
$folders = $coverageResults | Select-Xml -XPath "//package "        # folders

$xmlWriter = Open-XmlWriter -Path $coverageReport
Get-CodeCoverageReport -Folders $folders -ScriptPath $inputDir -xmlWriter $xmlWriter
Close-XmlWriter -XmlWriter $xmlWriter

Write-Host "Finished CodeCoverage" -ForegroundColor Green

#endregion codecoverage





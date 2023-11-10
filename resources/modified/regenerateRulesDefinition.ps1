

$reportFile = "C:\DEV\sonar-ps-plugin\sonar-ps-plugin\src\main\resources\powershell-rules.xml"
$profileFile = "C:\DEV\sonar-ps-plugin\sonar-ps-plugin\src\main\resources\powershell-profile.xml"

$xmlProfileWriter = New-Object System.XMl.XmlTextWriter($profileFile , $Null);
  # Set The Formatting
$xmlProfileWriter.Formatting = "Indented"
$xmlProfileWriter.Indentation = "4"

# Write the XML Declaration
$xmlProfileWriter.WriteStartDocument();

# Start Issues XML Element
$xmlProfileWriter.WriteStartElement("profile");
$xmlProfileWriter.WriteElementString("name", "Sonar way");
$xmlProfileWriter.WriteElementString("language", "ps");
$xmlProfileWriter.WriteStartElement("rules");

# Create The Document
$xmlWriter = New-Object System.XMl.XmlTextWriter($reportFile , $Null);

# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"

# Write the XML Declaration
$xmlWriter.WriteStartDocument();

# Start Issues XML Element
$xmlWriter.WriteStartElement("psrules");

$powershellRules = Get-ScriptAnalyzerRule

# added this line
$powershellRules += Get-ScriptAnalyzerRule -CustomRulePath "C:\DEV\BPOL\CodeReview\NewCode\CustomRules\*.psm1"

foreach ($rule in $powershellRules)
{
    $xmlProfileWriter.WriteStartElement("rule");
    $xmlProfileWriter.WriteElementString("key", $rule.RuleName);
    $xmlProfileWriter.WriteElementString("repositoryKey", "ps-psanalyzer");
    $xmlProfileWriter.WriteEndElement();

    $xmlWriter.WriteStartElement("rule");
    $xmlWriter.WriteElementString("key", $rule.RuleName)
    $xmlWriter.WriteElementString("internalKey", $rule.RuleName)
    $xmlWriter.WriteElementString("name", $rule.CommonName)

    # added this condition
    if([string]::IsNullOrEmpty($rule.Description))
    {
        throw "Every Rule needs a Description. Otherwise Sonarqube fails to start using this plugin: $($rule.RuleName)"
    }
    $xmlWriter.WriteElementString("description", $rule.Description)
    $xmlWriter.WriteElementString("cardinality", "SINGLE")
    $xmlWriter.WriteElementString("remediationFunction", "LINEAR")
    $xmlWriter.WriteElementString("descriptionFormat", "MARKDOWN")

    $xmlWriter.WriteElementString("remediationFunctionBaseEffort", "")
    $remediationDefaultTime = "2min";
    $severity = "INFO";

    if ($rule.Severity -eq "Information") {
        $severity = "INFO";
        $remediationDefaultTime = "2min";
    }
    if ($rule.Severity -eq "Warning") {
        $severity = "MAJOR";
        $remediationDefaultTime = "5min";
    }
    if ($rule.Severity -eq "ERROR") {
        $severity = "BLOCKER";
        $remediationDefaultTime = "15min";
    }
    $xmlWriter.WriteElementString("debtRemediationFunctionCoefficient", $remediationDefaultTime);
    $xmlWriter.WriteElementString("severity", $severity);
    $xmlWriter.WriteEndElement();
}

# End Issues XML element
$xmlWriter.WriteEndElement();

# End the XML Document
$xmlWriter.WriteEndDocument();

# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close();


$xmlProfileWriter.WriteEndDocument();


# Finish The Document
$xmlProfileWriter.Finalize
$xmlProfileWriter.Flush
$xmlProfileWriter.Close();
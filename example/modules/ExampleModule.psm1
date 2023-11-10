
function Get-MyName{
    return "Henry"
}

function Get-User
{
    param(

        [Parameter(Mandatory)]
        [string]$AccountName
    )

    $obj = New-Object -TypeName pscustomobject
    $obj | Add-Member -MemberType NoteProperty -Name sAMAccountName -Value $AccountName
    $obj | Add-Member -MemberType NoteProperty -Name l -Value "Munich"
    $obj | Add-Member -MemberType NoteProperty -Name streetAddress -Value "Karolinenplatz"

    $obj
}

function Get-Group
{
    param(

        [Parameter(Mandatory)]
        [string]$AccountName
    )

    $obj = New-Object -TypeName pscustomobject
    $obj | Add-Member -MemberType NoteProperty -Name sAMAccountName -Value $AccountName

    $obj
}

Export-ModuleMember -Function ("Get-User", "Get-Group")
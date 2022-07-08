<#
.SYNOPSIS
Create file from template

.DESCRIPTION
Expand variables and expressions in a template file to create a new file

.PARAMETER SourceFile
Path of the template file

.PARAMETER DestinationFile
Target file

.EXAMPLE
New-FileFromTemplate C:\Source\SQL-v1.template "C:\Temp\${Env:computername}_ConfigurationFile.ini"

#>
function New-FileFromTemplate {
param(
    [Parameter(Mandatory)]
    [string]
    $SourceFile,
    [Parameter(Mandatory)]
    [string]
    $DestinationFile   
)

if (Test-Path -Path $SourceFile) {
$template = Get-Content $SourceFile -Raw
$expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
Set-Content -Value $expanded -Path $DestinationFile -Force
}
else {
    throw [System.IO.FileNotFoundException] "$SourceFile not found/not accessible."
}

}

<#
.SYNOPSIS
List variables in a template

.DESCRIPTION
Get the list of Powershell variables in a template file

.PARAMETER SourceFile
Path of the source template file

.EXAMPLE
Get-VariablesFromTemplate C:\Source\SQL-2019.template

#>
function Get-VariablesFromTemplate {
    param(
        [Parameter(Mandatory)]
        [string]
        $SourceFile   
    )
    
    if (Test-Path -Path $SourceFile) {
        $template = Get-Content $SourceFile -Raw
        $expr = "@`"`r`n$template`r`n`"@"
        # TO-DO: AST parsing
        $abstractSyntaxTree = [System.Management.Automation.Language.Parser]::ParseInput($expr, 
                                 [ref]$null, [ref]$null)
        
        $varsExpressionList = $abstractSyntaxTree.FindAll( 
                    { $args[0] -is [System.Management.Automation.Language.VariableExpressionAst ] },
                       $true)
        
        $varsList = $varsExpressionList | Select-Object -ExpandProperty VariablePath

        $varsList
    }
    else {
        throw [System.IO.FileNotFoundException] "$SourceFile not found/not accessible."
    }
    
}

<#
.SYNOPSIS
Test if a variable exists

.DESCRIPTION
Returns $true if a variable has a defined contents

.PARAMETER VariablePath
VariablePath Object

.EXAMPLE
Get-VariablesFromTemplate | ForEach-Object { Test-Variable $_ }
#>
function Test-Variable {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.VariablePath]
        $VariablePath
    )
    Test-Path "Variable:\$($VariablePath.UserPath)" 
}

<#
.SYNOPSIS
Get Missing variables

.DESCRIPTION
Get a list of variables which aren't defined

.PARAMETER VariableList
Array of Variables

.EXAMPLE
$l = Get-VariablesFromTemplate C:\temp\tpl.template 
Get-MissingVariables $l

#>
function Get-MissingVariables {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.VariablePath[]]
        $VariableList
    )

    $missingVars = [System.Collections.ArrayList]::new()

    foreach ($v in $VariableList) {
        if (!(Test-Variable -VariablePath $v)) {
            $missingVars.Add($v.UserPath) | Out-Null
        }

    }

    $missingVars

}

<#
.SYNOPSIS
Test if a template is correctly expanded

.DESCRIPTION
Test if every variable in a template is well defined

.PARAMETER SourceFile
Path to the template

.PARAMETER Quiet
Returns true or false instead of a list of missingvariables

.PARAMETER AsException
Returns an exception instead of true false if at least one variable is missing

.EXAMPLE
Test-Template -SourceFile C:\temp\template1.tpl

.EXAMPLE
Test-Template -SourceFile C:\temp\template1.tpl -AsException
#>
function Test-Template {
    param(
        [Parameter(Mandatory)]
        [string]
        $SourceFile,
        [switch]
        $Quiet,
        [switch]
        $AsException
    )

    $varsList = Get-VariablesFromTemplate -SourceFile $SourceFile
    $missingVars = Get-MissingVariables -VariableList $varsList
    if ($AsException) {
        if ($missingVars.Count -ne 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new("Missing values for variables $($missingVars -join ', ').")
        }
    }
    if ($Quiet) {
        return $missingVars.Count -eq 0
    } else {
        $missingVars
    }
}

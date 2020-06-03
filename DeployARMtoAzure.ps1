<#
    .DESCRIPTION
        This Script deploys ARM templates to Microsoft Azure from a given folder structure via PowerShell
        Attention: To run properly, it needs the Az Module for PowerShell, at leat in Version 4.1.0
        To install it, run 
            Install-Module -Name Az -AllowClobber -MinimumVersion 4.1.0
        Be aware, that you need to either set a GitHub Secret for AZURE_CREDENTIALS when using GitHub Actions or use Connect-AzAccount when using the script without GitHub Actions
        When deploying to Tenant level, you need to set proper permission. To do so, use
            New-AzRoleAssignment -SignInName "[userId]" -Scope "/" -RoleDefinitionName "Owner"
                or
            az role assignment create --role "Owner" --assignee "[userId]" --scope "/"


    .NOTES
        AUTHOR: Haiko Hertes
                Microsoft MVP & Azure Architect
        LASTEDIT: 2020/06/03
#>

$ARMSubfolderName = "arm"
$TenantLevelFolderName = "1_TenantLevelDeployments"
$ManagementGroupLevelFolderName = "2_ManagementGroupLevelDeployments"
$SubscriptionLevelFolderName = "3_SubscriptionLevelDeployments"
$ResourceGroupLevelFolderName = "4_ResourceGroupLevelDeployments"

$SortOrderFile = "order.txt"
$SortOrderByFolderValue = "SortByFolderName"
$SortOrderByFileValue = "SortByFileName"

$DefaultLocationFileName = "DefaultLocation.txt"
$LocationFileName = "location.txt"
$UseRGLocationInsteadOfDefaultLocation = $true # When set to true, resource deployments without given location.txt file will just inherit RGs location

$ScopeFileName = "scope.txt"

$DefaultLocation = ((Get-Content "$(Join-Path -Path $PSScriptRoot -ChildPath $ARMSubfolderName)\$DefaultLocationFileName") -notmatch '^#')[0]

Clear-Host
Write-Host "$DefaultLocation will be used as default location."


function GetLocation([string]$Directory){
# Gets the location from given Path or uses default location
    If(Test-Path -Path (Join-Path  $Directory -ChildPath $LocationFileName))
        {                                                                                    # This is to ignore comments with '#'
            Return ((Get-Content -Path (Join-Path  $Directory -ChildPath $LocationFileName)) | Where {$_ -notmatch '^#.*'} | Select-Object -First 1)
        }
        else
        {
            Write-Host "    No $LocationFileName file found - using default location"
            Return $DefaultLocation
        }
}


function GetScope([string]$Directory){
# Gets the scope from given path - file content or foldername
    If(Test-Path -Path (Join-Path  $Directory -ChildPath $ScopeFileName))
        {                                                                                # This is to ignore comments with '#'
            Return ((Get-Content -Path (Join-Path $Directory -ChildPath $ScopeFileName)) | Where {$_ -notmatch '^#.*'} | Select-Object -First 1)
        }
        else
        {
            Write-Host "    No $ScopeFileName file found - using foldername as scope"
            Return (Split-Path $Directory -Leaf)
        }
}

Write-Host "`n-----------------------------------------------------------`n"

#region Tenant Level Deployments

# Checking if folder structure exists
$FolderName = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $ARMSubfolderName) -ChildPath $TenantLevelFolderName -Resolve -ErrorVariable folderDoesNotExist
If($folderDoesNotExist)
{
    Write-Host -ForegroundColor Red ">>> Tenant Level Folder $TenantLevelFolderName does not exist under $ARMSubfolderName - skipping this part!"
}
else
{
    # Tenant Level Deployment
    Write-Host ">>> Starting with the Tenant Level Deployments..."
    # Getting all template files that are json files but not parameters
    $templates = Get-ChildItem -Path $FolderName -Filter "*.json" -File -Recurse | Where Name -notlike "*parameters.json"
    Write-Host ">>  Found $($templates.Count) JSON template(s)..."
    
    # Sorting the files in the given order
    If(Test-Path "$FolderName\$SortOrderFile")
    {                                                 # This is to ignore comments with '#'
        If(((Get-Content "$FolderName\$SortOrderFile")| Where {$_ -notmatch '^#.*'} | Select-Object -First 1) -like "*$SortOrderByFileValue*")
        {
            Write-Host "    Sorting ByFileName..."
            $templates = $templates | Sort-Object -Property BaseName
        }
        else # Default - sort by foldername and filename 
        {
            Write-Host "    Sorting ByFolderName..."
            $templates = $templates | Sort-Object -Property Directory,BaseName
        }
    }
    Write-Host "`n>>  Will handle these files in the named order:"
    $templates.FullName.replace($PSScriptRoot,"")

    # Iterate through all template files and deploy them
    ForEach($template in $templates)
    {   
        Write-Host "`n>   Using $($template.Name)..."
        
        # Getting location from file or use default location
        $Location = GetLocation -Directory $template.DirectoryName
        Write-Host "    Location will be $Location"

        # Getting scope from file or folder name
        $Scope = GetScope -Directory $template.DirectoryName
        Write-Host "    Scope will be $Scope"

        # Setting scope to given value
        $Context = Set-AzContext -Tenant $Scope

    
        $Tags = @{}
        # Load Tags if tags.txt does exist
        # This needs to be so ugly for now as -Tag does not accept empty hashtable - so we need to have both options - with and without Tags
        If(Test-Path -Path "$($template.DirectoryName)\tags.txt")
        {
            $Tags = Get-Content "$($template.DirectoryName)\tags.txt" -Raw | ConvertFrom-StringData
            Write-Host "    Found and loaded Tags."
            # Starting the deployment            Write-Host "    Deploying $($template.Name)..."            $AzTenantDeployment = New-AzTenantDeployment `                -Name ($template.Basename) `                -Location $Location `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json" `
                -Tag $Tags
        }
        else
        {
            # Deployment without Tags
            Write-Host "    Deploying $($template.Name)..."            $AzTenantDeployment = New-AzTenantDeployment `                -Name ($template.Basename) `                -Location $Location `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json"
        }
    }
    Write-Host ">>> Done with the Tenant Level Deployments."
}
#endregion

Write-Host "`n-----------------------------------------------------------`n"

#region Management Group Level Deployments
$FolderName = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $ARMSubfolderName) -ChildPath $ManagementGroupLevelFolderName -Resolve -ErrorVariable folderDoesNotExist
If($folderDoesNotExist)
{
    Write-Host -ForegroundColor Red ">>> Management Group Level Folder $ManagementGroupLevelFolderName does not exist under $ARMSubfolderName - skipping this part!"
}
else
{
    # Management Group Level Deployment
    Write-Host ">>> Starting with the Management Group Level Deployments..."
    # Getting all template files that are json files but not parameters
    $templates = Get-ChildItem -Path $FolderName -Filter "*.json" -File -Recurse | Where Name -notlike "*parameters.json"
    Write-Host ">>  Found $($templates.Count) JSON template(s)..."
    
    # Sorting the files in the given order
    If(Test-Path "$FolderName\$SortOrderFile")
    {
        If(((Get-Content "$FolderName\$SortOrderFile") -notmatch '^#')[0] -like "*$SortOrderByFileValue*")
        {
            Write-Host "    Sorting ByFileName..."
            $templates = $templates | Sort-Object -Property BaseName
        }
        else # Default - sort by foldername and filename 
        {
            Write-Host "    Sorting ByFolderName..."
            $templates = $templates | Sort-Object -Property Directory,BaseName
        }
    }
    Write-Host "`n>>  Will handle these files in the named order:"
    $templates.FullName.replace($PSScriptRoot,"")

    # Iterate through all template files and deploy them
    ForEach($template in $templates)
    {   
        Write-Host "`n>   Using $($template.Name)..."
        
        # Getting location from file or use default location
        $Location = GetLocation -Directory $template.DirectoryName
        Write-Host "    Location will be $Location"

        # Getting scope from file or folder name
        $Scope = GetScope -Directory $template.DirectoryName
        Write-Host "    Scope will be $Scope"
        
        $Tags = @{}
        # Load Tags if tags.txt does exist
        # This needs to be so ugly for now as -Tag does not accept empty hashtable - so we need to have both options - with and without Tags
        If(Test-Path -Path "$($template.DirectoryName)\tags.txt")
        {
            $Tags = Get-Content "$($template.DirectoryName)\tags.txt" -Raw | ConvertFrom-StringData
            Write-Host "    Found and loaded Tags."
            # Starting the deployment            Write-Host "    Deploying $($template.Name)..."            $AzManagementGroupDeployment = New-AzManagementGroupDeployment `                -Name ($template.Basename) `                -ManagementGroupId $Scope `                -Location $Location `
                -Tag $Tags `
                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json"
        }
        else
        {
            # Deployment without Tags
            Write-Host "    Deploying $($template.Name)..."            $AzManagementGroupDeployment = New-AzManagementGroupDeployment `                -Name ($template.Basename) `                -ManagementGroupId $Scope `                -Location $Location `
                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json"
        }
    }
    Write-Host ">>> Done with the Management Group Level Deployments."
}
#endregion

Write-Host "`n-----------------------------------------------------------`n"

#region Subscription Level Deployments
$FolderName = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $ARMSubfolderName) -ChildPath $SubscriptionLevelFolderName -Resolve -ErrorVariable folderDoesNotExist
If($folderDoesNotExist)
{
    Write-Host -ForegroundColor Red ">>> Subscription Level Folder $SubscriptionLevelFolderName does not exist under $ARMSubfolderName - skipping this part!"
}
else
{
    # Subscription Level Deployment
    Write-Host ">>> Starting with the Subscription Level Deployments..."
    # Getting all template files that are json files but not parameters
    $templates = Get-ChildItem -Path $FolderName -Filter "*.json" -File -Recurse | Where Name -notlike "*parameters.json"
    Write-Host ">>  Found $($templates.Count) JSON template(s)..."
    
    # Sorting the files in the given order
    If(Test-Path "$FolderName\$SortOrderFile")
    {
        If(((Get-Content "$FolderName\$SortOrderFile") -notmatch '^#')[0] -like "*$SortOrderByFileValue*")
        {
            Write-Host "    Sorting ByFileName..."
            $templates = $templates | Sort-Object -Property BaseName
        }
        else # Default - sort by foldername and filename 
        {
            Write-Host "    Sorting ByFolderName..."
            $templates = $templates | Sort-Object -Property Directory,BaseName
        }
    }
    Write-Host "`n>>  Will handle these files in the named order:"
    $templates.FullName.replace($PSScriptRoot,"")

    # Iterate through all template files and deploy them
    ForEach($template in $templates)
    {   
        Write-Host "`n>   Using $($template.Name)..."
        
        # Getting location from file or use default location
        $Location = GetLocation -Directory $template.DirectoryName
        Write-Host "    Location will be $Location"

        # Getting scope from file or folder name
        $Scope = GetScope -Directory $template.DirectoryName
        Write-Host "    Scope will be $Scope"

        # Setting scope to given value
        $Context = Set-AzContext -Subscription $Scope

    
        $Tags = @{}
        # Load Tags if tags.txt does exist
        # This needs to be so ugly for now as -Tag does not accept empty hashtable - so we need to have both options - with and without Tags
        If(Test-Path -Path "$($template.DirectoryName)\tags.txt")
        {
            $Tags = Get-Content "$($template.DirectoryName)\tags.txt" -Raw | ConvertFrom-StringData
            Write-Host "    Found and loaded Tags."
            # Starting the deployment            Write-Host "    Deploying $($template.Name)..."            $AzSubscriptionDeployment = New-AzSubscriptionDeployment `                -Name ($template.Basename) `                -Location $Location `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json" `
                -Tag $Tags
        }
        else
        {
            # Deployment without Tags
            Write-Host "    Deploying $($template.Name)..."            $AzSubscriptionDeployment = New-AzSubscriptionDeployment `                -Name ($template.Basename) `                -Location $Location `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json"
        }
    }
    Write-Host ">>> Done with the Subscription Level Deployments."
}
#endregion

Write-Host "`n-----------------------------------------------------------`n"

#region Resource Group Level Deployments
$FolderName = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $ARMSubfolderName) -ChildPath $ResourceGroupLevelFolderName -Resolve -ErrorVariable folderDoesNotExist
If($folderDoesNotExist)
{
    Write-Host -ForegroundColor Red ">>> Resource Group Level Folder $ResourceGroupLevelFolderName does not exist under $ARMSubfolderName - skipping this part!"
}
else
{
    # Resource Group Level Deployment
    Write-Host ">>> Starting with the Resource Group Level Deployments..."
    # Getting all template files that are json files but not parameters
    $templates = Get-ChildItem -Path $FolderName -Filter "*.json" -File -Recurse | Where Name -notlike "*parameters.json"
    Write-Host ">>  Found $($templates.Count) JSON template(s)..."
    
    # Sorting the files in the given order
    If(Test-Path "$FolderName\$SortOrderFile")
    {
        If(((Get-Content "$FolderName\$SortOrderFile") -notmatch '^#')[0] -like "*$SortOrderByFileValue*")
        {
            Write-Host "    Sorting ByFileName..."
            $templates = $templates | Sort-Object -Property BaseName
        }
        else # Default - sort by foldername and filename 
        {
            Write-Host "    Sorting ByFolderName..."
            $templates = $templates | Sort-Object -Property Directory,BaseName
        }
    }
    Write-Host "`n>>  Will handle these files in the named order:"
    $templates.FullName.replace($PSScriptRoot,"")

    # Iterate through all template files and deploy them
    ForEach($template in $templates)
    {   
        Write-Host "`n>   Using $($template.Name)..."

        # Getting scope from file or folder name
        $Scope = GetScope -Directory $template.DirectoryName
        Write-Host "    Scope will be $Scope"

        ## Setting scope to given value
        #$Context = Set-AzContext -Subscription $Scope

    
        $Tags = @{}
        # Load Tags if tags.txt does exist
        # This needs to be so ugly for now as -Tag does not accept empty hashtable - so we need to have both options - with and without Tags
        If(Test-Path -Path "$($template.DirectoryName)\tags.txt")
        {
            $Tags = Get-Content "$($template.DirectoryName)\tags.txt" -Raw | ConvertFrom-StringData
            Write-Host "    Found and loaded Tags."
            # Starting the deployment            Write-Host "    Deploying $($template.Name)..."            $AzResourceGroupDeployment = New-AzResourceGroupDeployment `                -Name ($template.Basename) `                -ResourceGroupName $Scope `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json" `
                -Tag $Tags
        }
        else
        {
            # Deployment without Tags
            Write-Host "    Deploying $($template.Name)..."            $AzResourceGroupDeployment = New-AzResourceGroupDeployment `                -Name ($template.Basename) `                -ResourceGroupName $Scope `                -TemplateFile $template.FullName `                -TemplateParameterFile "$($template.DirectoryName)\$($template.BaseName).parameters.json"
        }
    }
    Write-Host ">>> Done with the Resource Group Level Deployments."
}
#endregion

Write-Host "Done with the whole script!"
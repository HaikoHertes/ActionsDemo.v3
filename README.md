# ActionsDemo.v3
A demo to show how to use GitHub Actions and PowerShell to deploy ARM templates on all available scopes for Azure (Tenant, MG, Subscription, RG)

The PowerShell Script expects a certain folder structure, use FolderStructure.7z to have an empty structure set up.

You can also adjust the names of expected files and folders in the upper part of DeployARMtoAzure.ps1

Be aware, that you need to either set a GitHub Scret for AZURE_CREDENTIALS when using GitHub Actions or use Connect-AzAccount when using the script without GitHub Actions
        When deploying to Tenant level, you need to set proper permission. To do so, use
            New-AzRoleAssignment -SignInName "[userId]" -Scope "/" -RoleDefinitionName "Owner"
                or
            az role assignment create --role "Owner" --assignee "[userId]" --scope "/"

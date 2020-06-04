# ActionsDemo.v3
A demo to show how to use GitHub Actions and PowerShell to deploy ARM templates on all available scopes for Azure (Tenant, MG, Subscription, RG)

The PowerShell Script expects a certain folder structure, use **FolderStructure.7z** to have an empty structure set up.

You can also adjust the names of expected files and folders in the upper part of **DeployARMtoAzure.ps1**.

Be aware, that you need to either set a **GitHub Secret** for AZURE_CREDENTIALS when using GitHub Actions or use Connect-AzAccount when using the script without GitHub Actions

When deploying to **Tenant level**, you need to set **proper permission**. To do so, use

`New-AzRoleAssignment -SignInName "[userId]" -Scope "/" -RoleDefinitionName "Owner"`

or

`az role assignment create --role "Owner" --assignee "[userId]" --scope "/"`

For a detailed explanation on how to use the script and stuff, visit https://www.hertes.net/2020/06/deploy-multiple-arm-templates-to-azure-using-powershell-and-github-actions/


**Copyright 2020 Haiko Hertes**

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

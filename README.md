# azure-wvdops-terraform

This repo will walk you through setting up the Azure infrastructure necessary to operate Windows Virtual Desktop which includes building custom images using [Azure Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder) and push to a [Azure Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries). You will need to have [Terraform](https://www.terraform.io/downloads.html) installed either locally on your machine or you can clone this repo in your [Azure Cloud Shell](https://shell.azure.com) which already has Terraform installed.

## Setup

1. Clone or use this repo as a template into your GitHub account

1. Read through these guides for background on Azure Image Builder:
    - https://github.com/Azure/build-vm-image
    - https://github.com/marketplace/actions/build-azure-virtual-machine-image

1. Make sure you have a service principal with the proper permissions in your subscription

    ```sh
    az ad sp create-for-rbac --name "myGitHubAction" --role contributor \
      --scopes <YOUR SCOPE> \
      --sdk-auth
    ```

    > Copy the contents to your clipboard

1. In your GitHub repo, head over to Settings and create a new Secret named `AZURE_CREDENTIALS` and paste in the content from the step above
1. While you are enter GitHub Secrets, you'll also need to enter the following to run the Terraform using GitHub Action:
  - ARM_CLIENT_ID
  - ARM_CLIENT_SECRET
  - ARM_SUBSCRIPTION_ID
  - ARM_TENANT_ID
1. Terraform requires you to manage state. I chose to use [Terraform Cloud](https://app.terraform.io) but there are other options such as [Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage). Whichever options you choose, you will need to update the [`backend.tf`](backend.tf) file to reflect your remote state. If you will be using Terraform Cloud too, you'll need to enter your [User API token](https://www.terraform.io/docs/cloud/users-teams-organizations/users.html#api-tokens) as a GitHub Secret named `TF_API_TOKEN`

## Troubleshooting Tips

- If you encounter errors in the workflow but there is no meaningful error message, then head over to your subscription and check the activity log. Chances are you may be running into a policy action.

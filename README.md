# azure-wvd

## Read through this guide

[](https://github.com/marketplace/actions/build-azure-virtual-machine-image)

## Build your infrastructure using Terraform supplied in the root of this repo

## Create a user-assigned managed identity

```sh
az identity create -g <RESOURCE GROUP> -n <USER ASSIGNED IDENTITY NAME>
```

> Keep the principalId value handy as you will need this for your custom role assignment

## Make sure you have a service principal with the proper permissions in your subscription

```sh
az ad sp create-for-rbac --name "myGitHubAction" --role contributor \
  --scopes <YOUR SCOPE> \
  --sdk-auth
```

> Copy the contents to your clipboard

## In your GitHub repo, head over to Settings and create a new Secret named `AZURE_CREDENTIALS` and paste in the content

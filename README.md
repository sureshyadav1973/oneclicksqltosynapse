# oneclicksqltosynapse
Migrate Sql server to Azure Synapse dedicated sql pool

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsureshyadav1973%2Foneclicksqltosynapse%2Fmain%2Fdeploy.json)

installsynapsepathway.ps1 - Install Synpase Pathway on VM

adddatabase.ps1           - Import and Create database on Sql server

exportddl.ps1             - Extract database objects DDL

gatewayinstall.ps1        - Install SHIR on VM and register with ADF

synapselinkedservices.ps1 - Install Synapse linked services

Te backup file use TPC-DS dataset ,below is the stor sales ER diagram

![image](https://user-images.githubusercontent.com/68124819/146087954-cce3d4a4-dd36-4f22-8c95-c7f106d1afa2.png)

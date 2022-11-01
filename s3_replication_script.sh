#!/bin/bash

#Creating an IAM role if exist don't need to create
aws iam create-role --role-name replicationRole --assume-role-policy-document file://s3-role-trust-policy.json --profile user
echo "The IAM role was created...."

#Create source bucket if not exist
function source_bucket_creation()
{
source_bucket_name="srivasanthsrc4"
source_bucket_region="us-east-1"
aws s3api create-bucket --bucket ${source_bucket_name} --region ${source_bucket_region} --profile user
echo "Source bucket ${source_bucket_name} was created...."

#Enabling versioning for the source bucket
aws s3api put-bucket-versioning --bucket ${source_bucket_name} --versioning-configuration Status=Enabled --profile user
echo "Source bucket ${source_bucket_name} versioning was enabled...."
}


function destination_bucket_creation()
{
#Create destination bucket 
destination_bucket_name="srivasanthdes4"
destination_bucket_region="us-east-1"
aws s3api create-bucket --bucket ${destination_bucket_name} --region ${destination_bucket_region} --profile user
echo "Destination bucket ${destination_bucket_name} was created...."

#Enabling versioning for the destination bucket
aws s3api put-bucket-versioning --bucket ${destination_bucket_name} --versioning-configuration Status=Enabled --profile user
echo "Destination bucket ${destination_bucket_name} versioning was enabled...."
}


function arn_Value()
{
#replicarionRole is the name of the IAM role
arnValue=`aws iam get-role --role-name replicationRole --output json --profile user| jq '.Role.Arn'`
#ArnValue will be parsed from json
arnValue=`echo "${arnValue}"|sed 's/"//g'`
}


function attach_Policy()
{
#Attaching policy to the IAM role for enabling replication access of s3
sed -i "s/sag-source-bucket/${source_bucket_name}/g" ./s3-role-permissions-policy.json
sed -i "s/sag-destination-bucket/${destination_bucket_name}/g" ./s3-role-permissions-policy.json
aws iam put-role-policy --role-name replicationRole --policy-document file://s3-role-permissions-policy.json --policy-name ${source_bucket_name}_policy --profile user
echo "The policy: ${source_bucket_name}_policy was added to the IAM role..."

#Reverting the source and destination bucket names for the next bucket
sed -i "s/${source_bucket_name}/sag-source-bucket/g" ./s3-role-permissions-policy.json
sed -i "s/${destination_bucket_name}/sag-destination-bucket/g" ./s3-role-permissions-policy.json
}

function create_replication_rule()
{
sed -i "s|ARN|${arnValue}|g" ./replication.json
sed -i "s/sag-destination-bucket/${destination_bucket_name}/g" ./replication.json
echo "ARN value : ${arnValue}"
echo "The replication.json"
cat ./replication.json
#Apply the rule
aws s3api put-bucket-replication --replication-configuration file://replication.json --bucket ${source_bucket_name} --profile user
echo "The replication rule was created ..."
#Getting the replication rule details
aws s3api get-bucket-replication --bucket ${source_bucket_name} --profile user

#Reverting the ARN and destination names for the next bucket
sed -i "s|${arnValue}|ARN|g" ./replication.json
sed -i "s/${destination_bucket_name}/sag-destination-bucket/g" ./replication.json
}

source_bucket_creation
destination_bucket_creation
arn_Value
attach_Policy
create_replication_rule

# aws s3api delete-bucket --bucket ${source_bucket_name} --profile user  
# aws s3api delete-bucket --bucket ${destination_bucket_name} --profile user 


#!/bin/bash

path=$(dirname $0) 
clusterId=$(cat $path/../installer-files/infraID)

if [ -z "$clusterId" ]; then
  exit 
fi

echo "0 - Start processing for cluster $clusterId - waiting for masters to be destroyed"
masters=3
while [ $masters -gt 0 ]; do
  nodes=$(aws ec2 describe-instances --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned"  Name="instance-state-name",Values="running" --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`] | [0].Value]' --output text)
  masters=$(echo "$nodes" | grep master | wc -l) 
  echo "Waiting for masters to be destroyed - $masters remaining"
  if [ $masters -gt 0 ]; then
    sleep 10
  fi
done
workers=$(echo "$nodes" | cut -d$'\t' -f1)

echo "1 - Deleting workers - $workers -"
if [ ! -z "$workers" ]; then 
  aws ec2 terminate-instances --instance-ids ${workers} 
fi

# Delete if they chose classic ELB
elbname=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text | xargs -I {} aws elb describe-tags --load-balancer-names {} --query "TagDescriptions[?Tags[?Key=='kubernetes.io/cluster/${clusterId}' && Value=='owned']].LoadBalancerName" --output text)
echo "2 - Deleting classic apps load balancers - $elbname - "
if [ ! -z "$elbname" ]; then 
  aws elb delete-load-balancer --load-balancer-name ${elbname}
  sleep 30
fi


# Delete if they chose NLB ELB
elbnamearn=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[].LoadBalancerArn' | xargs -I {} aws elbv2 describe-tags --resource-arns {} --query "TagDescriptions[?Tags[?Key=='kubernetes.io/cluster/${clusterId}' && Value=='owned']].ResourceArn" --output text)
echo "3 - Deleting NLB apps load balancers - $elbnamearn - "
if [ ! -z "$elbnamearn" ]; then 
  aws elbv2 delete-load-balancer --load-balancer-arn $elbnamearn
fi

# New section to delete ELBv2 targets
target_groups=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[].TargetGroupArn' | xargs -I {} aws elbv2 describe-tags --resource-arns {} --query "TagDescriptions[?Tags[?Key=='kubernetes.io/cluster/${clusterId}' && Value=='owned']].ResourceArn" --output text)
echo "3.1 - Deleting ELBv2 target groups - $target_groups -"
if [ ! -z "$target_groups" ]; then
  for tg in $(echo $target_groups | tr '\t' '\n'); do
    echo "Deleting target group - $tg"
    aws elbv2 delete-target-group --target-group-arn $tg
  done
  sleep 30
fi

sg=$(aws ec2 describe-security-groups --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'SecurityGroups[].[GroupId,GroupName]' --output text | grep "k8s-elb" | cut -d$'\t' -f1)

echo "4 - Deleting elb security group - $sg -"
while [ ! -z "$sg" ]; do
  aws ec2 delete-security-group --group-id ${sg}
  sleep 10
  sg=$(aws ec2 describe-security-groups --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'SecurityGroups[].[GroupId,GroupName]' --output text | grep "k8s-elb" | cut -d$'\t' -f1)
done

s3imagereg=$(aws s3 ls | grep ${clusterId} | awk '{print $3}') 
echo "5 - Deleting S3 image-registry $s3imagereg -"
if [ ! -z "$s3imagereg" ]; then
  aws s3 rb --force s3://$s3imagereg
fi
iamusers=$(aws iam list-users --query 'Users[].[UserName,UserId]' --output text | grep ${clusterId})
echo "6 - Deleting iamusers - $iamusers"
if [ ! -z "$iamusers" ]; then
  echo "$iamusers" | awk '{print "aws iam delete-user-policy --user-name "$1" --policy-name "$1"-policy"}' | bash
  echo "$iamusers" | awk '{print "aws iam delete-access-key --user-name "$1" --access-key-id $(aws iam list-access-keys --user-name "$1" --query 'AccessKeyMetadata[].AccessKeyId' --output text)"}' | bash
  echo "$iamusers" | awk '{print "aws iam delete-user --user-name "$1}' | bash
fi
exit 0


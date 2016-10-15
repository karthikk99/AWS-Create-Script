#!/bin/bash

# check the number of parameters passed.
parameters=$#

if [ $# -ne 5 ]
then
echo "This script requires 2 parameters to be passed(Key name and security group).Please pass the right number of parameters and run the script again."

else
securitygroupid=$3

echo ""
echo "Creating 3 EC2 micro instances........."
aws ec2 run-instances --image-id $1 --key-name $2 --security-group-id $3 --instance-type t2.micro --count $5 --user-data file://installenv.sh --placement AvailabilityZone=us-west-2b
echo ""
echo "Successfully created 3 instances."

instances1=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Placement.AvailabilityZone, State.Name, InstanceId]' --output text | grep us-west-2b | grep 'pending' | awk '{print $3}')

echo "" 
echo "waiting for the instances to come to 'running' status........"   
aws ec2 wait instance-running --instance-ids $instances1
echo ""
echo "All the instances are in running status"

instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Placement.AvailabilityZone, State.Name, InstanceId]' --output text | grep us-west-2b | grep 'running' | awk '{print $3}')

echo ""
echo "The following are the three instances in running status........"
echo $instances

echo ""
echo "The following are the subnets id created for the three instances..........."
subnetids=$(aws ec2 describe-subnets --query 'Subnets[].SubnetId' --output text)
echo $subnetids
echo ""
echo "Creating a load balancer named 'MY-LOAD-BALANCER'......"
aws elb create-load-balancer --load-balancer-name my-load-balancer --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --availability-zones us-west-2b --security-groups $securitygroupid
echo "MY-LOAD-BALANCER is successfully created."

echo ""
echo "Creating Launch configuration......."
aws autoscaling create-launch-configuration --launch-configuration-name $4 --image-id ami-06b94666 --key-name $1 --instance-type t2.micro --user-data file://installenv.sh
echo ""
echo "Launch configuration 'WEBSERVER' is successfully created."

echo ""
echo "Creating a auto-scaling-group named 'WEBSERVERDEMO' with min-size 1 max-size 5 desired capacity 1........"
aws autoscaling create-auto-scaling-group --auto-scaling-group-name webserverdemo --launch-configuration $4 --availability-zone us-west-2b --max-size 5 --min-size 1 --desired-capacity 1
echo ""
echo "WEBSERVERDEMO is successfully created."

echo ""
echo "Registering the already 3 created instances to the load balancer 'MY-LOAD-BALANCER'......."
aws elb register-instances-with-load-balancer --load-balancer-name my-load-balancer --instances $instances
echo ""
echo "3 instances registered to the load balancer"
echo ""

echo "Attaching the instances to the auto scaling group 'WEBSERVERDEMO'.........."
aws autoscaling attach-instances --instance-ids $instances --auto-scaling-group-name webserverdemo
echo ""
echo "Instances successfully attached to the auto-scaling-group" 

echo ""
echo "Updating the auto-scaling-group to the new desired capacity value"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name webserverdemo --launch-configuration-name $4 --min-size 1 --max-size 5 --desired-capacity 4 --availability-zones us-west-2b


echo ""
echo "The script run is successful. 4 instances are running which are attached to the auto scaling group and 3 are registered to the load balancer."
echo ""
echo "-----------------------------------------------------------------------------------------------------------"

fi


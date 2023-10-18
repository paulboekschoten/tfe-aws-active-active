# diagram.py

from diagrams import Cluster, Diagram
from diagrams.aws.general import Client
from diagrams.aws.network import Route53
from diagrams.aws.network import InternetGateway
from diagrams.aws.network import NATGateway
from diagrams.aws.network import ElbApplicationLoadBalancer
from diagrams.aws.compute import EC2AutoScaling
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.database import ElasticacheForRedis
from diagrams.aws.storage import SimpleStorageServiceS3Bucket


with Diagram("TFE Active-active", show=False, direction="TB"):
    
    user = Client("User")

    with Cluster("AWS"):

        route53 = Route53("DNS record")

        with Cluster("VPC"):
            igw = InternetGateway("Internet Gateway")

            #AZ:a
            with Cluster("Availability Zone: eu-west3a"):
              with Cluster("Public Subnet 2"):
                alb_a = ElbApplicationLoadBalancer("ALB")
            
              with Cluster("Private Subnet 2"):
                asg_a = EC2AutoScaling("Autoscaling Group \n TFE instance")
                postgres_a = RDSPostgresqlInstance("PostgresSQL")
                redis_a = ElasticacheForRedis("Redis")

            #AZ:a
            with Cluster("Availability Zone: eu-west3c"):
              with Cluster("Public Subnet"):
                nat = NATGateway("NAT gateway")
                alb_c = ElbApplicationLoadBalancer("ALB")
            
              with Cluster("Private Subnet"):
                asg_c = EC2AutoScaling("Autoscaling Group \n TFE instance")
                #postgres_c = RDSPostgresqlInstance("PostgresSQL")
                #redis_c = ElasticacheForRedis("Redis")

        s3bucket = SimpleStorageServiceS3Bucket("TFE bucket")
        s3bucketfiles = SimpleStorageServiceS3Bucket("TFE install \n files bucket")

    user >> route53
    user >> alb_a
    user >> alb_c
    alb_a >> asg_a
    alb_a >> asg_c
    alb_c >> asg_a
    alb_c >> asg_c
    asg_a >> postgres_a
    asg_c >> postgres_a
    asg_a >> redis_a
    asg_c >> redis_a
    asg_a >> s3bucket
    asg_c >> s3bucket
    asg_a >> s3bucketfiles
    asg_c >> s3bucketfiles

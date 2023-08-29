# diagram.py

from diagrams import Cluster, Diagram
from diagrams.aws.general import Client
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.storage import SimpleStorageServiceS3Bucket


with Diagram("TFE Airgapped", show=False, direction="TB"):
    
    client = Client("Client")

    with Cluster("AWS"):
        with Cluster("VPC"):
            with Cluster("Public Subnet"):
                tfe_instance = EC2("Terraform Enterprise")
            
            with Cluster("Private Subnet"):
                postgres = RDSPostgresqlInstance("PostgresSQL")

        s3bucket = SimpleStorageServiceS3Bucket("S3 bucket")

    client >> tfe_instance
    tfe_instance >> postgres
    tfe_instance >> s3bucket

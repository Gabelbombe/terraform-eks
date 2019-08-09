# ECR for EKS - GabelBombe/debian-openjdk11
module "ecr-debian-openjdk11" {
  source = "../ecr"
  prefix = "${var.prefix}"
  env    = "${var.env}"
  region = "${var.region}"
  name   = "eks-ecr/gabelbombe/debian-openjdk11"
}

# ECR for EKS - GabelBombe/simple-server-clojure-single-node
module "ecr-simple-server-clojure-single-node" {
  source = "../ecr"
  prefix = "${var.prefix}"
  env    = "${var.env}"
  region = "${var.region}"
  name   = "eks-ecr/gabelbombe/simple-server-clojure-single-node"
}

# ECR for EKS - GabelBombe/simple-server-clojure-dynamodb
module "ecr-simple-server-clojure-dynamodb" {
  source = "../ecr"
  prefix = "${var.prefix}"
  env    = "${var.env}"
  region = "${var.region}"
  name   = "eks-ecr/gabelbombe/simple-server-clojure-dynamodb"
}

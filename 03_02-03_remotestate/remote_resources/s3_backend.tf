# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "bucket_name" {
  default = "red30-tfstate"
}

# //////////////////////////////
# PROVIDER
# //////////////////////////////
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "us-east-2"
}

# //////////////////////////////
# TERRAFORM USER
# //////////////////////////////
data "aws_iam_user" "terraform" {
  user_name = "terraform"
}

# //////////////////////////////
# S3 BUCKET
# //////////////////////////////
resource "aws_s3_bucket" "red30-tfremotestate" {
  bucket = "${var.bucket_name}-${formatdate("DD-MM-YYYY", timestamp())}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "red30-tfremotestate" {
  bucket = aws_s3_bucket.red30-tfremotestate.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "red30-tfremotestate" {
  bucket = aws_s3_bucket.red30-tfremotestate.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.red30-tfremotestate.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "${aws_s3_bucket.red30-tfremotestate.id}",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${data.aws_iam_user.terraform.arn}"
            },
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.red30-tfremotestate.id}/*"
        }
    ]
}
EOF
}

resource "aws_s3_bucket_public_access_block" "red30-tfremotestate" {
  bucket = aws_s3_bucket.red30-tfremotestate.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# //////////////////////////////
# DYNAMODB TABLE
# //////////////////////////////
resource "aws_dynamodb_table" "tf_db_statelock" {
  name           = "red30-tfstatelock"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# //////////////////////////////
# IAM POLICY
# //////////////////////////////
resource "aws_iam_user_policy" "terraform_user_dbtable" {
  name = "terraform"
  user = data.aws_iam_user.terraform.user_name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${aws_dynamodb_table.tf_db_statelock.arn}"
            ]
        }
   ]
}

EOF
}


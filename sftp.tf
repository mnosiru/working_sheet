resource "aws_iam_role" "sftp_role" {
  name = "tf-test-transfer-server-iam-role-${local.workspace_env}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

#Set SFTP user permissions.
resource "aws_iam_role_policy" "sftp_policy" {
  name = "tf-test-transfer-server-iam-policy-${local.workspace_env}"
  role = aws_iam_role.sftp_role.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowFullAccesstoCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "*"
        },
        {
			    "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ],
         "Resource": [
            "arn:aws:s3:::${local.sftp_bucket_name}"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:GetObjectVersion",
            "s3:GetObjectACL",
            "s3:PutObjectACL"
          ],
          "Resource": [
            "arn:aws:s3:::${local.sftp_bucket_name}/${local.sftp_user}/*"
        ]
      }
    ]
}
POLICY
}

resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.sftp_role.arn

  tags = {
    Name        = "tf-acc-test-transfer-server-${local.workspace_env}"
    environment = local.environment
    Owner       = var.owner_name
  }
}

#create a folder for the user in S3 bucket which was previourly created. ( not part of this code )
resource "aws_s3_bucket_object" "s3_folder" {
  depends_on = [aws_s3_bucket.b]
  bucket     = local.sftp_bucket_name
  #bucket       = "sftp-bucket-ny2"
  key          = "${local.sftp_user}/"
  content_type = "application/x-directory"
  //  (Optional) Specifies the AWS KMS Key ARN to use for object encryption. This value is a fully qualified ARN of the KMS Key. 
  #kms_key_id = "${var.kms_key_arn}"
}

#create sftp user 
resource "aws_transfer_user" "ftp_user" {
  depends_on     = [aws_s3_bucket.b]
  server_id      = aws_transfer_server.sftp_server.id
  user_name      = local.sftp_user
  role           = aws_iam_role.sftp_role.arn
  home_directory = "/${local.sftp_bucket_name}/${local.sftp_user}"
}

#SSH key for user to manage sftp account
#Generate SSH key using PuttyGen
resource "aws_transfer_ssh_key" "ssh_key" {
  server_id = aws_transfer_server.sftp_server.id
  user_name = aws_transfer_user.ftp_user.user_name
  body      = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEApjf+e/na2t1iIX2mSSyR3ll5VrlpxHS8THx9PIOPnoNXC5y4ERS7tJ/n50RiS6y9QiGKl0dDQvCaIVL0Ydj3NSYENKKYZ694vwro0uCH8FgmUEaofqWT9gogCsdj1SRLVhHzLub7Yqt4iFcXlM3RvMTUl0bwjowe5yyiWWKJL3ycwC+USEDgL1vsyS7zm4RcyC/FIn6oKoc/Y5rfoR+WWBLnSU8L1605sE4X/Z2GGb4JQj4VlopmBXLW9CyST5eXb0U5FU6+nL30fZVpgFim0IpBj4hCYyTClxwztl1WW9jmiCRM2JPdbv5TazJC1wxPx6NJDqrVmmcxClpLy3q+oQ== rsa-key-20200405"
}

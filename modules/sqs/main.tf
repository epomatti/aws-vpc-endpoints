resource "aws_sqs_queue" "private_queue" {
  name = "my-private-queue"
}

resource "aws_sqs_queue_policy" "allow_ec2_role" {
  queue_url = aws_sqs_queue.private_queue.url

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Id      = "sqspolicy"

      Statement = [
        {
          Sid    = "1"
          Effect = "Allow"
          Action = [
            "sqs:SendMessage"
          ]
          Principal = {
            AWS = "${var.ec2_iam_role_arn}"
          }
          Resource = "${aws_sqs_queue.private_queue.arn}"
        },
        {
          Sid    = "2"
          Effect = "Deny"
          Action = [
            "sqs:SendMessage"
          ]
          Principal = "*"
          Resource  = "${aws_sqs_queue.private_queue.arn}"
          Condition = {
            StringNotEquals = {
              "aws:sourceVpce" : "${var.vpce_id}"
            }
          }
        },
      ]
    }
  )
}

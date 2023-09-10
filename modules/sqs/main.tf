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
          Effect = "Allow"
          Action = [
            "sqs:SendMessage"
          ]
          Principal = {
            AWS = "${var.ec2_iam_role_arn}"
          }
          Resource = "${aws_sqs_queue.private_queue.arn}"
        }
      ]
    }
  )
}

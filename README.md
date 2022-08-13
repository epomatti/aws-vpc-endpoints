# aws-vpc-interface-endpoints-sandbox



aws sts get-caller-identity

sqs.sa-east-1.amazonaws.com

TF should output this example command:

```sh
aws sqs send-message --queue-url 'https://sqs.sa-east-1.amazonaws.com/000000000000/my-private-queue' --message-body "Hello"
```

Run it to test the command.

Reference: [Basic Amazon SQS policy examples](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-basic-examples-of-sqs-policies.html)
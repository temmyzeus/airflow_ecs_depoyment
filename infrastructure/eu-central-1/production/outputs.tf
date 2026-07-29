output "gh_action_iam_role_arn" {
  type        = string
  description = "ARN of the IAM Role to be assumed by Github Actions"
  value       = "IAM Role for GitHub Actions Role: ${aws_iam_role.gh_action_role.arn}"
}

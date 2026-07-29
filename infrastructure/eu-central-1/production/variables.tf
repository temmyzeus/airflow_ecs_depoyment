variable "github_repos" {
  type        = list(string)
  description = "List of GitHub repositories allowed for OIDC authentication & ECR Deployment"
  # repo:<owner>@<owner_id>/<repo_name>@<repo_id>:ref:refs/heads/branch_name
  default   = ["repo:temmyzeus@63079698/airflow_ecs_depoyment@1307735006:ref:refs/heads/master"]
  sensitive = false
  nullable  = false

  validation {
    condition     = alltrue([for repo in var.github_repos : substr(repo, 0, 5) == "repo:"])
    error_message = "Repostories must be in the format 'repo:<owner>/<repo>:*' and must be a list of strings."
  }
}

provider "kubernetes" {
  # The provider resolves "~" with mitchellh/go-homedir, which on Windows
  # reads the HOME environment variable. Under Git Bash, HOME is a POSIX
  # path ("/c/Users/...") that the Go resolver cannot expand, so the
  # kubeconfig is never found and the provider silently falls back to an
  # empty config, i.e. http://localhost.
  #
  # Resolving the path here with Terraform's own pathexpand() avoids that:
  # it goes through USERPROFILE, which is always a native Windows path.
  # Terraform's pathexpand() only expands "~", so the result is a plain
  # absolute path and the provider expands it to itself.
  config_path = coalesce(var.kubeconfig_path, pathexpand("~/.kube/config"))

  # Left unset by default: the provider then uses the current context of the
  # kubeconfig, like kubectl does. Set it to pin a specific cluster.
  config_context = var.kube_context
}

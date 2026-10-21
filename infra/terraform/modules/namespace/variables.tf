variable "name" {
  description = "Name of the namespace."
  type        = string
}

variable "labels" {
  description = "Labels applied to the namespace."
  type        = map(string)
  default     = {}
}

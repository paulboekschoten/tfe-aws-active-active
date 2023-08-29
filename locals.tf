locals {
  any_port      = 0
  any_icmp_port = -1
  any_protocol  = "-1"
  tcp_protocol  = "tcp"
  all_ips       = "0.0.0.0/0"
  fqdn          = "${var.route53_subdomain}.${var.route53_zone}"
}
output "cluster_id" {
  value = yandex_kubernetes_cluster.vulnapp.id
}

output "cluster_external_endpoint" {
  value = yandex_kubernetes_cluster.vulnapp.master[0].external_v4_endpoint
}

output "cluster_name" {
  value = yandex_kubernetes_cluster.vulnapp.name
}
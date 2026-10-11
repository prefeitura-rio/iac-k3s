# Bot Discord que dispara os deployments Prefect da Nota Carioca (namespace prefect).
# O GitRepository precisa se chamar "prefect" (= namespace): o ImageUpdateAutomation
# gerado pelo base-chart referencia o GitRepository pelo nome do namespace.
resource "kubectl_manifest" "discord_nota_carioca_jobs_gitrepo" {
  depends_on = [kubernetes_namespace_v1.prefect, helm_release.flux_instance, kubernetes_secret_v1.fluxcd_git_auth]

  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = "prefect"
      namespace = "prefect"
    }
    spec = {
      interval = "1m"
      url      = "https://github.com/prefeitura-rio/app-discord-nota-carioca-jobs.git"
      ref = {
        branch = "master"
      }
      secretRef = {
        name = "flux-git-auth"
      }
    }
  })
}

resource "kubectl_manifest" "discord_nota_carioca_jobs_kustomization" {
  depends_on = [kubernetes_namespace_v1.prefect, kubectl_manifest.discord_nota_carioca_jobs_gitrepo, kubernetes_secret_v1.ghcr_credentials]

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = "app-discord-nota-carioca-jobs"
      namespace = "prefect"
    }
    spec = {
      interval = "1m"
      prune    = true
      sourceRef = {
        kind = "GitRepository"
        name = "prefect"
      }
      path = "./k8s/prod"
    }
  })
}

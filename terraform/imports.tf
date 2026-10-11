# Objetos do bot do Discord criados direto com kubectl em 2026-10-11, antes de o state migrar para
# module.deployments. No primeiro apply estes blocos adotam os objetos existentes em vez de tentar
# recriá-los (o que falharia com "already exists"); depois disso não fazem nada e podem ser apagados.
import {
  to = module.deployments.kubernetes_secret_v1.fluxcd_git_auth["prefect"]
  id = "prefect/flux-git-auth"
}

import {
  to = module.deployments.kubernetes_secret_v1.ghcr_credentials["prefect"]
  id = "prefect/ghcr-credentials"
}

import {
  to = module.deployments.kubectl_manifest.discord_nota_carioca_jobs_gitrepo
  id = "source.toolkit.fluxcd.io/v1//GitRepository//prefect//prefect"
}

import {
  to = module.deployments.kubectl_manifest.discord_nota_carioca_jobs_kustomization
  id = "kustomize.toolkit.fluxcd.io/v1//Kustomization//app-discord-nota-carioca-jobs//prefect"
}

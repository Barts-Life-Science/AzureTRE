locals {
  core_vnet                       = "vnet-${var.tre_id}"
  core_resource_group_name        = "rg-${var.tre_id}"
  nexus_allowed_fqdns             = "pypi.org,*.pypi.org,files.pythonhosted.org,security.ubuntu.com,archive.ubuntu.com,keyserver.ubuntu.com,repo.anaconda.com,*.docker.com,*.docker.io,*.6aa30f8b08e16409b46e0173d6de2f56.r2.cloudflarestorage.com,conda.anaconda.org,azure.archive.ubuntu.com,packages.microsoft.com,repo.almalinux.org,download-ib01.fedoraproject.org,cran.r-project.org,cloud.r-project.org,download1.rstudio.org,*.snapcraftcontent.com,download.microsoft.com,marketplace.visualstudio.com,registry.ollama.ai,registry.ollama.com,dd20bb891979d25aebc8bec07b2b3bbc.r2.cloudflarestorage.com,huggingface.co,*.huggingface.co,*.hf.co"
  nexus_allowed_fqdns_list        = distinct(compact(split(",", replace(local.nexus_allowed_fqdns, " ", ""))))
  # e8.* entries are for Let's Encrypt E8 (ECDSA) intermediate — the actual CA used
  # by the App Gateway cert. Windows Schannel walks the full chain and checks CRL/OCSP
  # for each cert, so all three endpoints must be reachable over HTTP (port 80).
  # r3.o.lencr.org is kept for deployments whose cert was issued by the R3 (RSA) intermediate.
  workspace_vm_allowed_fqdns      = "r3.o.lencr.org,x1.c.lencr.org,e8.o.lencr.org,e8.i.lencr.org,e8.c.lencr.org"
  workspace_vm_allowed_fqdns_list = distinct(compact(split(",", replace(local.workspace_vm_allowed_fqdns, " ", ""))))
  storage_account_name            = lower(replace("stg-${var.tre_id}", "-", ""))
  tre_shared_service_tags = {
    tre_id                = var.tre_id
    tre_shared_service_id = var.tre_resource_id
  }
  cmk_name                 = "tre-encryption-${var.tre_id}"
  encryption_identity_name = "id-encryption-${var.tre_id}"
}

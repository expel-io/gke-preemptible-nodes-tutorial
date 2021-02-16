Assumes you have:
- gcloud setup with account with required permissions
Create a project
Enable billing
Enable APIs
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
might fail / timeout first time

note about gcr.io acces

resource "google_storage_bucket_iam_member" "cluster_registry_access" {
  bucket = "artifacts.expel-engineering-devops.appspot.com"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cluster.email}"
}


gcloud container clusters get-credentials preemptible-2 --zone us-east1

note about auto upgrade and auto repair
note about new cluster entering repairing state

gcloud container clusters resize --zone us-east1 --node-pool preemptible-fallback preemptible-3 --num-nodes 0

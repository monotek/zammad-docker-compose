# Zammad kubernetes example deployment (pre beta)

The zammad-nfs container is some proof of concept for shared storage. This
container is only needed if you store Zammads articles in the filesystem as
zammads rails-server, scheduler & websocket-server  needs to acces it. If you
save all articles to the postgresql db you don't need the nfs container.
Be aware that storing articles in db is discouraged on larger installations.


## Prerequisites

- Change the ingress to your needs.


## Deploy zammad

### Install on Minikube example

* Install kubectl
  * https://kubernetes.io/docs/tasks/tools/install-kubectl/
* Install Minkube
  * https://github.com/kubernetes/minikube
* minikube start --memory=4096 --cpus=2
* minikube addons enable ingress
* echo "$(minikube ip) zammad.example.com" | sudo tee -a /etc/hosts
* kubectl apply -f .
* minikube dashboard
  * switch to namespace "zammad"
  * open "Overview" and wait until all pods are green
* access zammad on:
  * http://zammad.example.com

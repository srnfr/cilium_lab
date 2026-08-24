# cilium_lab

Laboratoire de démonstration autour de Cilium, Kubernetes, kind, Containerlab et FRRouting. Le dépôt sert à reproduire des scénarios réseau et sécurité sur des clusters locaux ou sur une machine virtuelle DigitalOcean.

Le dépôt est un environnement de test. Les versions, les images et les scripts ne sont pas figés de manière homogène et les manifestes ne constituent pas une configuration de production.

## Vue d’ensemble

| Répertoire | Rôle | Parcours principal |
| --- | --- | --- |
| `basic/` | Cluster kind mono-cluster et essais CNI | Cilium, Calico, Ingress, Hubble, politiques réseau |
| `clustermesh/` | Deux clusters kind interconnectés | Cilium Cluster Mesh et services globaux |
| `bgp-cplane-demo/` | Topologie réseau Containerlab avec FRR | Cilium BGP Control Plane et LoadBalancer IPAM |
| `gateway-api/` | Fragments Gateway API | HTTP, HTTPS, certificats ACME, canary et routage par en-tête |
| `policies/` | Exemples de workloads et politiques | CiliumNetworkPolicy, NetworkPolicy et NodePort |
| `sol/` | Fragment d’application | Deployment, Service et ancien Ingress NGINX |
| `tf/` | Provisionnement DigitalOcean | Droplets Ubuntu et bootstrap cloud-init |
| `nico/` | Variante de la démonstration BGP | Copie expérimentale de la topologie BGP |
| racine | Utilitaires et initialisation distante | Kubeconfig, inspection BPF et génération de trafic |

## Prérequis

Pour les scénarios locaux, prévoir :

- Linux avec Docker fonctionnel et les privilèges nécessaires pour créer des conteneurs, interfaces et réseaux.
- `kubectl`, `kind`, Helm, Cilium CLI, Hubble CLI et Containerlab.
- Une connexion Internet pour télécharger les images, les binaires et certains manifestes distants.
- Au moins 4 vCPU et 8 Go de mémoire pour le scénario BGP. Le scénario Cluster Mesh utilise deux clusters kind.
- Un répertoire de travail cohérent. Les scripts de `basic/` sont principalement conçus pour être lancés depuis `basic/` et certains scripts supposent que le dépôt se trouve dans `/home/cilium_lab`.

Le script `basic/00-build-foundation.sh` installe une partie de ces outils sur Ubuntu. Il modifie le système, installe des paquets, installe Docker, Containerlab, kind, Helm, Cilium CLI, Hubble CLI et K9s. Il doit être lu et adapté avant exécution sur une machine existante.

## Démarrage rapide avec DigitalOcean

Le répertoire `tf/` crée des droplets DigitalOcean. Le fichier `tf/common.auto.tfvars` contient des valeurs communes, mais plusieurs variables obligatoires restent à fournir :

- `do_token`
- `droplet_count`
- `root_password`
- `ghrepo`

Exemple de séquence :

```bash
cd tf
terraform init
terraform plan \
  -var="do_token=$DIGITALOCEAN_TOKEN" \
  -var='droplet_count=1' \
  -var='root_password=CHANGER_CE_MOT_DE_PASSE' \
  -var='ghrepo=https://example.invalid/organisation/cilium_lab.git'
terraform apply \
  -var="do_token=$DIGITALOCEAN_TOKEN" \
  -var='droplet_count=1' \
  -var='root_password=CHANGER_CE_MOT_DE_PASSE' \
  -var='ghrepo=https://example.invalid/organisation/cilium_lab.git'
```

Le template `tf/cloud-init.yaml.tpl` installe les paquets et Krew pour `kubectl`, active l'accès SSH par mot de passe, clone le dépôt dans `/home/cilium_lab`, puis lance `basic/00-build-foundation.sh`.

Les Droplets sont ensuite associés au projet DigitalOcean existant `LAB` avec leurs URN. Le projet n'est pas créé ni supprimé par ce dépôt. La variable `digitalocean_project_name` peut être laissée avec sa valeur par défaut `LAB` ou remplacée dans Terraform Cloud.

Le workspace crée aussi un record DNS de type `A` pour chaque Droplet, avec le format `<préfixe>-<index>.<zone>`. Avec le préfixe par défaut fourni par le code et une zone configurée dans TFC, les noms suivent le format demandé `vm-X.<zone>`. Le record pointe vers l'adresse IPv4 publique du Droplet, n'est pas proxifié par Cloudflare et est supprimé automatiquement lorsque le Droplet correspondant est supprimé de l'état Terraform.

Variables Terraform Cloud à configurer dans le workspace `ws-rS638MJGsFaaGCCZ` :

- `do_token`, sensible, token DigitalOcean existant ;
- `cloudflare_api_token`, sensible, token Cloudflare avec les permissions de zone `Zone Read` et `DNS Write` sur la zone ;
- `cloudflare_zone_id`, non sensible, identifiant de zone Cloudflare ;
- `dns_zone_name`, non sensible, nom de domaine géré, sans le publier dans le dépôt ;
- `digitalocean_project_name`, facultative, valeur par défaut `LAB` ;
- `droplet_count`, `root_password` et `ghrepo`, selon la configuration déjà utilisée par le workspace.

Le `zone_id` suffit pour cette ressource DNS. Le nom de domaine reste uniquement une valeur de variable Terraform Cloud et n'est pas ajouté au dépôt. L'identifiant de compte Cloudflare n'est pas consommé par cette configuration.

Cette procédure expose des risques importants si elle est utilisée telle quelle : mot de passe root en clair dans les variables et potentiellement dans l'état Terraform, `PasswordAuthentication yes`, `PermitRootLogin yes`, dépôt cloné sans référence de commit et téléchargement de scripts distants. Elle est adaptée à un laboratoire isolé, pas à un serveur exposé.

## Scénario basic avec Cilium

Le scénario `basic/` crée un cluster kind nommé `basic` avec un plan de contrôle et trois workers. Le CNI par défaut de kind est désactivé. Le fichier `basic/values.yaml` configure Cilium avec :

- mode de routage natif ;
- kube-proxy conservé, car `kubeProxyReplacement` est désactivé dans ce fichier ;
- IPAM Kubernetes ;
- NodePort et HostPort activés ;
- Hubble Relay et Hubble UI activés.

Séquence recommandée depuis la racine du dépôt :

```bash
kind delete cluster --name basic 2>/dev/null || true
kind create cluster --config=basic/kind-config.yaml

cd basic
./reconfigure-cilium.sh
./check-cilium.sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
kubectl apply -f ingress-test.yaml
curl http://localhost/foo
curl http://localhost/bar
```

Le script `basic/05-install-cilium-cluster.sh` regroupe presque cette séquence. Les scripts `basic/01-install-cluster.sh` et `basic/05-install-cilium-cluster.sh` commencent par `kind delete ... && kind create ...`, ce qui échoue si le cluster n'existe pas encore. `basic/01-install-cluster.sh` contient en plus un `exit` avant l'installation de Cilium et de l'Ingress. Il est donc préférable d'utiliser la séquence explicite ci-dessus ou de corriger ces scripts avant de les automatiser.

### Variantes Cilium

Les fichiers `basic/ebpf-values.yaml`, `basic/ebpf-values-nokubeproxy.yaml`, `basic/noepf-values.yaml`, `basic/mtls-values.yaml` et `basic/ztunnel-values.yaml` sont des profils de configuration alternatifs. Ils ne sont pas utilisés par le parcours basic par défaut.

Ils couvrent notamment :

- remplacement de kube-proxy par eBPF et mode DSR ;
- routage natif sans kube-proxy ;
- authentification mutuelle avec SPIRE ;
- chiffrement avec ztunnel.

Ces profils doivent être appliqués avec `helm upgrade --install` après avoir vérifié leur compatibilité avec la version de Cilium utilisée. `basic/gen-ztunnel-secrets.sh` génère des clés et certificats temporaires dans `/tmp`, puis crée le secret `cilium-ztunnel-secrets` dans `kube-system`.

### Applications et politiques

- `basic/ingress-test.yaml` déploie deux pods `foo` et `bar`, leurs Services et un Ingress basé sur les chemins `/foo` et `/bar`.
- `basic/frontend-deployment.yaml` et `basic/frontend-svc.yaml` constituent un frontend Guestbook exposé en NodePort.
- `basic/cnp-allow-from-frontend.yaml` autorise le frontend Guestbook à atteindre Redis leader.
- `basic/np-allow-from-redis-and-frontend.yaml` est une politique Kubernetes standard d'ingress vers Redis leader.
- `policies/nodeport.yaml` déploie un service NodePort `toto-service`.

Les noms `policies/allow-to-foo.yaml` et `policies/deny-to-bar.yaml` doivent être vérifiés avant démonstration. En particulier, `deny-to-bar.yaml` contient une règle `ingress: - {}`, qui ne correspond pas à un refus explicite et peut autoriser l'ingress selon la sémantique Cilium. Le nom du fichier ne suffit donc pas à décrire le comportement réel.

Vérification et nettoyage :

```bash
cd basic
./check-cilium.sh
./check-routes.sh
kubectl get pods -A
kind delete cluster --name basic
```

Les scripts `clean-kind.sh` et `10-destroy-all.sh` peuvent supprimer plusieurs clusters kind, pas uniquement le cluster basic. Les utiliser seulement dans un environnement dédié.

## Scénario Cluster Mesh

Le répertoire `clustermesh/` crée deux clusters kind : `mesh1` et `mesh2`. Les réseaux de pods sont distincts : `10.1.0.0/16` et `10.2.0.0/16`. Les clusters utilisent des contextes kubectl `kind-mesh1` et `kind-mesh2`.

Exécution :

```bash
cd clustermesh
./01-build-clusters.sh
./02-install-cilium.sh
./03-enable-clustermesh.sh
```

Le deuxième script installe Cilium 1.19.3, partage le secret `cilium-ca` de `mesh1` vers `mesh2`, active Cluster Mesh en NodePort et attend l'état ready. Le troisième script connecte les deux clusters.

Pour tester un service global :

```bash
kubectl --context kind-mesh1 apply -f echo-cluster1.yaml
kubectl --context kind-mesh2 apply -f echo-cluster2.yaml
kubectl --context kind-mesh1 apply -f client.yaml
kubectl --context kind-mesh1 exec client -- curl -s http://echo.default.svc.cluster.local
```

Les deux Services `echo` portent les annotations Cilium `service.cilium.io/global` et `service.cilium.io/shared`. Ils permettent de publier le même service dans le mesh et de répartir les requêtes entre les clusters.

État et nettoyage :

```bash
cilium clustermesh status --context kind-mesh1 --wait
cilium clustermesh status --context kind-mesh2 --wait
./10-destroy-all.sh
```

## Scénario BGP Control Plane

`bgp-cplane-demo/` relie un cluster kind à une topologie Containerlab composée de :

- `router0`, AS 65000, routeur central FRR ;
- `tor0`, AS 65010, associé au rack 0 ;
- `tor1`, AS 65010 côté FRR, associé au rack 1 ;
- quatre nœuds `server0` à `server3`, attachés aux conteneurs kind correspondants.

Le cluster kind est nommé `clab-bgp-cplane-demo`. Ses nœuds utilisent les adresses `10.0.1.2` à `10.0.4.2` et les labels `rack=rack0` ou `rack=rack1`. Cilium utilise le routage natif, l'IPAM Kubernetes et le BGP Control Plane.

Séquence :

```bash
cd bgp-cplane-demo
./01-build-kind-cluster.sh
./02-deploy-containerlab.sh
./03-install-cilium.sh
./04-enable-bgp-cilium.sh
kubectl get ciliumbgpclusterconfig,ciliumbgppeerconfig,ciliumbgpadvertisement
```

Le fichier `04-enable-bgp-cilium.sh` applique la configuration actuellement privilégiée, basée sur `CiliumBGPAdvertisement`, `CiliumBGPPeerConfig` et une configuration par rack. Les fichiers `cilium-bgp-cluster-config.yaml`, `cilium-bgp-node-config.yaml`, `cilium-bgp-peering-policies.yaml` et `cilium-configmap.yaml` représentent d'autres générations de l'API ou d'autres approches. Ne pas appliquer toutes ces variantes simultanément sans vérifier la version de Cilium.

Pour annoncer une adresse LoadBalancer :

```bash
kubectl apply -f cilium-iploadbalancer-ippool.yaml
kubectl apply -f lbsvc.yaml
kubectl get svc test-lb -w
./showbgp.sh tor0
./showbgp.sh tor1
```

Le pool `192.0.2.0/24` est une plage réservée à la documentation. Le Service `test-lb` est sélectionné par le label `bgp=blue`, reçoit une adresse du pool et est annoncé par BGP. `showbgp.sh` interroge FRR avec `vtysh` dans le conteneur Containerlab ciblé.

Nettoyage :

```bash
./10-destroy-all.sh
```

Le script de nettoyage parcourt tous les clusters kind présents sur la machine. La topologie peut également laisser des artefacts générés dans `clab-bgp-cplane-demo/`.

## Gateway API et certificats

`gateway-api/` ne constitue pas un scénario autonome. Les fichiers supposent que les éléments suivants existent déjà :

- les CRD Gateway API ;
- Cilium installé avec la fonctionnalité Gateway API et une `GatewayClass` nommée `cilium` ;
- cert-manager installé pour les fichiers ACME ;
- `demo-service`, `demo-service-v1` et `demo-service-v2` ;
- un DNS public pointant vers la passerelle pour l'ACME HTTP-01.

Les fichiers sont des variantes à appliquer selon le besoin :

- `gateway-http.yaml` crée une Gateway HTTP et une route simple vers `demo-service` ;
- `gateway-https.yaml` ajoute les listeners HTTP et HTTPS et référence `demo-gateway-tls` ;
- `certificate.yaml` demande le certificat `grpX.randco.eu` ;
- `clusterissuer-letsencrypt.yaml` configure l'ACME Let's Encrypt en production ;
- `canary-route.yaml` répartit le trafic entre deux Services ;
- `header-route.yaml` route les requêtes portant `X-Version: v2` vers la version 2.

Les valeurs `grpX.randco.eu`, `groupeGRP.randco.eu` et `admin@null.com` sont des placeholders. Elles doivent être remplacées avant application. `gateway-http.yaml` et `gateway-https.yaml` définissent tous deux `demo-gateway`, ils doivent être considérés comme deux variantes et non comme deux manifestes à appliquer ensemble.

`sol/ingress.tpl` est un ancien exemple Ingress NGINX et fournit seulement `demo-service`. Il ne crée pas les Services v1 et v2 référencés par les routes canary et header.

## Provisionnement et fichiers auxiliaires

À la racine :

- `init.sh <groupe> <entropy>` télécharge un kubeconfig depuis un stockage DigitalOcean, vérifie l'accès au cluster et installe Cilium CLI, Hubble CLI, Krew, Helm et K9s si nécessaire.
- `list-tracking.sh` affiche la table BPF conntrack globale de Cilium.
- `list-tunnels.sh` affiche les tunnels BPF de Cilium.
- `massive-curl.sh` envoie 100 requêtes vers `172.18.0.5:30760`. L'adresse et le port sont codés en dur et doivent être adaptés au scénario.

Les fichiers `bgp-cplane-demo/clab-*/topology-data.json`, `authorized_keys`, `.tls/` et les fichiers `.bak` sont des artefacts ou des restes de générations Containerlab. Ils ne sont pas nécessaires à la compréhension du parcours principal et doivent être traités comme des données potentiellement sensibles ou périmées.

## Limites et points à traiter

L'analyse du dépôt fait apparaître les points suivants :

- Les versions de kind, Cilium, Calico, FRR et des images conteneur ne sont pas centralisées.
- Plusieurs scripts n'utilisent pas `set -euo pipefail` et peuvent continuer après une erreur.
- Certains scripts dépendent du répertoire courant ou de chemins absolus comme `/home/cilium_lab`.
- Le script `basic/gen-ztunnel-secrets.sh` se termine par la commande résiduelle `SCRIPT`, qui provoquera une erreur après la création du secret.
- `nico/ds.yaml` commence par `piVersion` au lieu de `apiVersion` et n'est pas un manifeste Kubernetes valide.
- Des certificats Containerlab sont expirés et des fichiers `authorized_keys` sont suivis par Git. Ces artefacts doivent être régénérés ou retirés du dépôt si le dépôt est partagé.
- Les manifestes Gateway API utilisent des domaines, une adresse e-mail et des Services d'exemple non définis.
- `tf/common.auto.tfvars` contient un identifiant de clé SSH DigitalOcean et le bootstrap active l'accès root par mot de passe.
- `basic/01-install-cluster.sh` contient un `exit` placé avant sa logique d'installation.
- Le scénario BGP contient des API Cilium de générations différentes. La version 1.19.3 utilisée par les scripts doit être alignée avec les CRD appliquées.

## Nettoyage global

Les commandes suivantes sont destructives pour les environnements de laboratoire concernés :

```bash
kind delete cluster --name basic
kind delete cluster --name mesh1
kind delete cluster --name mesh2
kind delete cluster --name clab-bgp-cplane-demo
containerlab -t bgp-cplane-demo/topo.yaml destroy
```

Vérifier les clusters et les topologies actifs avant de lancer un script `clean-kind.sh` ou `10-destroy-all.sh`, car ces scripts peuvent cibler plus de ressources que le scénario courant.

## Vérifications effectuées pour cette documentation

La documentation a été construite à partir de la structure Git, des scripts shell, des valeurs Helm, des manifestes Kubernetes, de la topologie Containerlab et de la configuration Terraform. Une vérification syntaxique `bash -n` des scripts shell a été effectuée. Aucun cluster, droplet ou déploiement n'a été créé pendant l'analyse.

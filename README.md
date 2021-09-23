# Installation OKD sur BareMetal

On utilise Fedora CoreOS comme système d'exploitation pour installer OKD sur des machines physiques.

Pour déployer un cluster a trois noeuds on a besoin de 4 machines:

    kube01: master0
    kube02: master1
    kube03: master2
    kube04: bootstrap
    kube05: worker0
    kube06: worker1
    kube07: worker2

La machine bootstrap est temporaire, c'est celle qui va déployer le cluster sur les autres noeuds.

Voici les infpormations pour ce cluster:

    Zone DNS pour le cluster: kube.lacave.info
    Nom du cluster: kubelacave
## PXE Boot
Avec OKD, il est suggéré de provisionner les hôtes en utilisant pxelinux au lieu de l'image ISO. Cette section décrit comment le faire avec isc-dhcp-server, tftpd-hpa et pxelinux sous Ubuntu 20.04.

Pour ce document, on utilise les adresses MAC suivant. Les ajuster en fonction des adresses MAC de vos machines:

    kube01: AA-AA-AA-AA-AA-AA
    kube02: AA-AA-AA-AA-AA-AB
    kube03: AA-AA-AA-AA-AA-AC
    
### DHCP
Pour utiliser pxelinux afin de provisionner les machines physiques (et/ou virtuelles) du custer on doit avoir un serveur dhcp. Dans ce projet on utilise isc-dhcp server sous Ubuntu 20.04.

Installer le logiciel:

    sudo apt install isc-dhcp-server
    sudo systemctl enable isc-dhcp-server
    sudo systemctl start isc-dhcp-server


Pour PXE, on doit ajouter les lignes dans le fichier /etc/dhcp/dhcpd.conf
Référence: https://wiki.syslinux.org/wiki/index.php?title=PXELINUX

Paramètres généraux

    allow booting;
    option space pxelinux;
    option pxelinux.magic      code 208 = string;
    option pxelinux.configfile code 209 = text;
    option pxelinux.pathprefix code 210 = text;
    option pxelinux.reboottime code 211 = unsigned integer 32;

Section pour le sous-réseau. La seule ligne ajoutée pour le pxe dans cette section est option bootfile-name

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.100 192.168.1.200;
  option domain-name "lacave";
  option domain-name-servers 192.168.1.10;
  option routers 192.168.1.1;
  default-lease-time 600;
  max-lease-time 7200;
  option bootfile-name "/pxelinux.0";
  site-option-space "pxelinux";
  option pxelinux.magic f1:00:74:7e;
  if exists dhcp-parameter-request-list {
    # Always send the PXELINUX options (specified in hexadecimal)
    option dhcp-parameter-request-list = concat(option dhcp-parameter-request-list,d0,d1,d2,d3);
  }
  option pxelinux.configfile = concat("pxelinux.cfg/", binary-to-ascii(16, 8, ":", hardware));
  option pxelinux.reboottime 30;
}

Redémarrer le service dhcp

    systemctl restart isc-dhcp-server
    systemctl status isc-dhcp-server

En cas de problème de configuration, les messages d'erreurs se retrouvent dans le fichier /var/log/syslog

Installer tftpd

    sudo apt install pxelinux
    sudo systemctl start tftpd-hpa
    sudo systemctl enable tftpd-hpa

Télécharger les fichiers nécessaire au démarrage d'un noyeaux permettant l'installation pour FCOS

    mkdir data
    docker run --privileged -ti --rm -v $(pwd):/data -w /data quay.io/coreos/coreos-installer:release download -f pxe

Copier les fichiers nécessaires dans le répertoire du serveur tftp (pour Ubuntu /srv/tftp)

Fichiers FCOS

    sudo cp data/* /srv/tftp

Fichiers pxelinux
    sudo cp /boot/pxelinux.0 /srv/tftp
    sudo cp /boot/ldlinux.c32 /srv/tftp

Créer les fichiers de configutations pxeboot pour les noeuds du cluster. Le nom du fichier de configuration pour chacun des noeud doit correspondre à son adresse MAC préfixé de 1 (je ne sais pas pourquoi le 1)

Voici les fichiers à créer:

    sudo mkdir /srv/tftp/pxelinux.cfg

Pour kube01: /srv/tftp/pxelinux.cfg/1:aa:aa:aa:aa:aa:aa 

    DEFAULT pxeboot
    TIMEOUT 20
    PROMPT 0
    LABEL pxeboot
        KERNEL fedora-coreos-33.20210426.3.0-live-kernel-x86_64
        APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-33.20210426.3.0-live-initramfs.x86_64.img,fedora-coreos-33.20210426.3.0-live-rootfs.x86_64.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://192.168.1.10/okd/kube01.ign coreos.inst.insecure
    IPAPPEND 2

Pour kube02: /srv/tftp/pxelinux.cfg/1:aa:aa:aa:aa:aa:ab 

    DEFAULT pxeboot
    TIMEOUT 20
    PROMPT 0
    LABEL pxeboot
        KERNEL fedora-coreos-33.20210426.3.0-live-kernel-x86_64
        APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-33.20210426.3.0-live-initramfs.x86_64.img,fedora-coreos-33.20210426.3.0-live-rootfs.x86_64.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://192.168.1.10/okd/kube02.ign coreos.inst.insecure
    IPAPPEND 2

Pour kube03: /srv/tftp/pxelinux.cfg/1:aa:aa:aa:aa:aa:ac

    DEFAULT pxeboot
    TIMEOUT 20
    PROMPT 0
    LABEL pxeboot
        KERNEL fedora-coreos-33.20210426.3.0-live-kernel-x86_64
        APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-33.20210426.3.0-live-initramfs.x86_64.img,fedora-coreos-33.20210426.3.0-live-rootfs.x86_64.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://192.168.1.10/okd/kube03.ign coreos.inst.insecure
    IPAPPEND 2

Pour kube04: /srv/tftp/pxelinux.cfg/1:aa:aa:aa:aa:aa:ad

    DEFAULT pxeboot
    TIMEOUT 20
    PROMPT 0
    LABEL pxeboot
        KERNEL fedora-coreos-33.20210426.3.0-live-kernel-x86_64
        APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-33.20210426.3.0-live-initramfs.x86_64.img,fedora-coreos-33.20210426.3.0-live-rootfs.x86_64.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://192.168.1.10/okd/kube04.ign coreos.inst.insecure
    IPAPPEND 2

Dans notre installation, Un serveur DNS bind est installé sur le serveur de provisionning.
Le fichier de zone pour lacave.info est /etc/bind/lacave.info.db

## Load Balancer
Pour le moment, il n'y a pas de load balancer mais il est nécessaire d'en avoir un pour le bon fonctionnement du cluster.
Le Load balancer devrait balancer la charge pour les ports suivants:
    6443 vers kube01, kube02, kube03 et kube04. kube04 sera retiré à la fin de l'installation du cluster
    22623 vers kube01, kube02, kube03 et kube04. kube04 sera retiré à la fin de l'installation du cluster

### Load Balancer NGINX

J'ai installé NGINX sur l'hôte Centos qui héberge les VM des noeuds kube04, kube05, kube06 et kube07.
Source : https://www.cyberciti.biz/faq/configure-nginx-ssltls-passthru-with-tcp-load-balancing/
Pour installer nginx:

    sudo dnf install -y nginx

Modifier la section suivante du fichier /etc/nginx/nginx.conf pour libérer le port 80:

    server {
        listen       8080 default_server;
        listen       [::]:8080 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

Ajouter les lignes suivantes au fichier /etc/nginx/nginx.conf

    include /etc/nginx/passthrough.conf;

Copier le fichier nginx/passthrough.conf de ce projet dans le répertoire /etc/nginx.

Redémarrer Nginx

    sudo systemctl reload nginx

## Préparation du DNS

Dans notre installation, Un serveur DNS bind est installé sur le serveur de provisionning.
Le fichier de zone pour lacave.info est /etc/bind/lacave.info.db
La zone DNS lacave.info sera utilisé pour le cluster.

La procédure d'installation de bind et de la création de la zone n'est pas encore incluse dans ce document: A venir.

On a besoin des entrés suivantes:
$ORIGIN lacave.info.
$TTL 3600       ; 1 hour
dns1                    A       192.168.1.10
lb                      A       192.168.1.20
kube01                  A       192.168.1.21
master0.kubelacave.kube CNAME   kube01.lacave.info.
kube02                  A       192.168.1.22
master1.kubelacave.kube CNAME   kube02.lacave.info.
kube03                  A       192.168.1.23
master2.kubelacave.kube CNAME   kube03.lacave.info.
kube04                  A       192.168.1.24
bootstrap.kubelacave.kube       CNAME   kube04.lacave.info.
lb.kubelacave.kube      CNAME   lb.lacave.info.

kube                    CNAME   lb.kubelacave.kube.lacave.info.
api.kubelacave.kube     CNAME   lb.kubelacave.kube.lacave.info.
api-int.kubelacave.kube CNAME   lb.kubelacave.kube.lacave.info.
helper.kubelacave.kube  CNAME   lb.kubelacave.kube.lacave.info.
*.kube                  CNAME   kube.lacave.info.
*.kubelacave.kube       CNAME   kube.lacave.info.

Les entrés helper.kubelacave.kube, api.kubelacave.kube et api.kubelacave.kube doivent résoudre vers l'adresse du bootstrap lors de l'installation initiale.
Un fois le cluster démarré, on doit changer la destination pour master0.kubelacave.kube.lacave.info.
Les entrés devront alors être modifiées pour:

    api.kubelacave.kube     CNAME   master0.kubelacave.kube.lacave.info.
    api-int.kubelacave.kube CNAME   master0.kubelacave.kube.lacave.info.
    kube                    CNAME   master1.kubelacave.kube.lacave.info.

Cette étape n'est plus nécessaire parce qu'on a un load balancer et que le DNS est configuré pour l'utiliser. 

## Fichier ignition de base pour les noeuds
Pour la configurtation des serveurs, on créé un fichier Yaml.

Pour nos besoins, le fichier contient le user root avec la clé rsa à ajouter à sez authorozed_keys, une adresse IP fixe et un nom d'hôte.

La structure est la suivante pour nos 4 machines:

    kube01.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.21/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube01
    kube02.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.22/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube02
    kube03.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.23/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube03
    kube04.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/ens3.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=ens3

            [ipv4]
            method=manual
            addresses=192.168.1.24/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube01


Pour créer le fichier ignition en format JSON utilisable par le processus d'installation, lancer les commandes suivantes:

    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube01.fcc > kube01.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube02.fcc > kube02.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube03.fcc > kube03.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube04.fcc > kube04.ign

Pour l'installation, on doit mettre les fichiers *.ign sur un serveur Web. Dans mopn cas, je les ai mis sur mon serveur elrond qui est en Ubuntu et qui a Apache installé dessus, dans le répertoire /var/www/html/okd

## Installation de OKD

Source: https://docs.okd.io/latest/installing/installing_bare_metal/installing-bare-metal.html

La première étape est de se créer un répertoire dans lequel mettre les fichiers utilisés et générées pendant l'installation.

Pour ce document, j'utilise le répertoire okd

    mkdir ~/okd

### Télécharger les outils

Clients:

    cd ~/okd
    wget https://github.com/openshift/okd/releases/download/4.7.0-0.okd-2021-09-19-013247/openshift-client-linux-4.7.0-0.okd-2021-09-19-013247.tar.gz
    tar -zxvf openshift-client-linux-4.7.0-0.okd-2021-09-19-013247.tar.gz
    sudo cp oc /usr/local/bin

Install:

    cd ~/okd
    wget https://github.com/openshift/okd/releases/download/4.7.0-0.okd-2021-09-19-013247/openshift-install-linux-4.7.0-0.okd-2021-09-19-013247.tar.gz
    tar -zxvf openshift-install-linux-4.7.0-0.okd-2021-09-19-013247.tar.gz


### Créer la clé ssh pour l'usager core des noeuds du cluster

On peut décider de créer un pair de clé pour accéder au serveurs du cluster.
Utililier les commandes suivantes pour créer une clé publique et un clé privé pour se connecter au noeuds du cluster.
    cd ~/okd
    mkdir keys
    ssh-keygen -t ed25519 -C "votre@adresse.courriel" -N '' -f keys/kubelacave-key 
On peut aussi décider d'utiliser cette de notre usager Unix courant qui se trouve dans ~/.ssh/id_rsa.pub

### Créer le fichier install-config.yaml
La première étape est de récupérer le pull Secret du site de RedHat. Pour se faire vous devez avoir un compte de développeur.
Aller sur le site https://cloud.redhat.com/openshift/install/pull-secret
Récupérer le secret soit en téléchargeant ou en faisant un copier du secret.

Le fichier install-config.yaml ressemble à ceci:
apiVersion: v1
baseDomain: kube.lacave.info
compute: 
- hyperthreading: Enabled 
  name: worker
  replicas: 0 
controlPlane: 
  hyperthreading: Enabled 
  name: master
  replicas: 3 
metadata:
  name: kubelacave
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14 
    hostPrefix: 23 
  networkType: OVNKubernetes
  serviceNetwork: 
  - 172.30.0.0/16
platform:
  none: {} 
pullSecret: 'Mettre le pull secret récupéré du site Openshift'
sshKey: 'Mettre le contenu du fichier keys/kubelacave-key.pub'

Créer le répertoire pour les manifest:

    mkdir -P ~/okd/manifest

Déposer le fichier dans le même répertoire que les outils téléchargés: ~/okd/manifest

### Créer le manifest
Lancer la commande suivante à partir du répertoire contenant les outils et le fichier install-config.yaml

    cd ~/okd
    ./openshift-install create manifests --dir=manifest

### Créer les fichier ignition
Lancer la commande suivante pour générer les fichier ignition de base pour Fedora CoreOS.

    ./openshift-install create ignition-configs --dir=manifest

Cette commande va créer les fichiers suivants:

    bootstrap.ign
    master.ign
    worker.ign

Il faut ensuite fusionner le contenu de ces fichiers avec les fichier ign déjà existant de nos noeuds.
Pour le cluster, on fusionne le fichier bootstrap.ign avec kueb04.ign
et le fichier master.ign avec les fichiers kueb01.ign. kube02.ign et kube03.ign
On dépose ensuite les fichiers dans le répertoire /var/www/html/okd

Un truc pour faire la mise en page du fichier ign c'est d'utiliser jq. Exemple:

    cat bootstrap.ign | jq > kube04.ign
    cat master.ign | jq > kube01.ign
    cat master.ign | jq > kube02.ign
    cat master.ign | jq > kube03.ign
    cat worker.ign | jq > kube05.ign
    cat worker.ign | jq > kube06.ign
    cat worker.ign | jq > kube07.ign

La partie à fusionner est dans la section storage files. On doit ajouter les fichiers suivants dans le fichier ignition pour la configuration du réseau:

    /etc/hostname
    /etc/NetworkManager/system-connections/NOMINTERFACERESEAU.nmconnection

On doit modifier les fichiers de configurations pxe de chacun des noeuds pour utiliser le bon fichier ign: http://192.168.1.10/okd/kube0X.ign

    /srv/tftp/pxelinux.cfg/MACDUNOEUD

    DEFAULT pxeboot
    TIMEOUT 20
    PROMPT 0
    LABEL pxeboot
        KERNEL fedora-coreos-33.20210426.3.0-live-kernel-x86_64
        APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-33.20210426.3.0-live-initramfs.x86_64.img,fedora-coreos-33.20210426.3.0-live-rootfs.x86_64.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://192.168.1.10/okd/kube03.ign coreos.inst.insecure
    IPAPPEND 2

S'il y a un système d'exploitation sur les noeuds, il peut être nécessaire de le remettre à 0 en utilisant les commandes suivantes:

    DISK="/dev/sda"
    # Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
    # You will have to run this step for all disks.
    sudo sgdisk --zap-all $DISK
    # Clean hdds with dd
    sudo dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync status=progress

## Déploiement du cluster

Démarrer premièrement le bootstrap. Dans notre cas kube04.

On peut suivre l'installation en se connectant sur le bootstrap kube04

Lanser la commande suivantes:
    ssh root@kube04
    journalctl -b -f -u release-image.service -u bootkube.service

Après l'installation initiale, le bootstrap va redémarrer

On peut ensuite démarrer les 3 noeuds.

On peut surveiller l'état d'avancement du déploiement des noeuds avec la commande suivante:

    ./openshift-install --dir=manifest wait-for bootstrap-complete --log-level=info
    INFO Waiting up to 20m0s for the Kubernetes API at https://api.kubelacave.kube.lacave.info:6443... 
    INFO API v1.20.0-1058+7d0a2b269a2741-dirty up     
    INFO Waiting up to 30m0s for bootstrapping to complete... 
    INFO It is now safe to remove the bootstrap resources 
    INFO Time elapsed: 14m48s   

Cette commande indique quand le cluster devient disponible.

A partir du moment ou il indique que l'API est disponible, on peut utiliser la commande oc pour monitorer l'état d'avancement du déploiement des noeuds:

    export KUBECONFIG=manifest/auth/kubeconfig
    watch -n5 oc get nodes

    NAME     STATUS   ROLES    AGE   VERSION
    kube01   Ready    master   16m   v1.20.0+7d0a2b2-1058
    kube02   Ready    master   16m   v1.20.0+7d0a2b2-1058
    kube03   Ready    master   16m   v1.20.0+7d0a2b2-1058


Un fois les 3 noeuds master disponible, on peut surveiller l'état d'avancement du déploiement des opérateurs de base avec la commande suivantes:

    watch -n5 oc get clusteroperators

On peut se connecter sur les noeuds en ssh avec la commande:

    ssh -i keys/kubelacave-key core@kube01

Un fois le processus de bootstrap terminé, c'est très long ca peut prendre plus de 45 minutes, on doit modifier les entrés DNS suvantes:

    kube                    CNAME   bootstrap.kubelacave.kube.lacave.info.
    api.kubelacave.kube     CNAME   bootstrap.kubelacave.kube.lacave.info.
    api-int.kubelacave.kube CNAME   bootstrap.kubelacave.kube.lacave.info.
    helper.kubelacave.kube  CNAME   bootstrap.kubelacave.kube.lacave.info.

Pour:

    kube                    CNAME   master1.kubelacave.kube.lacave.info.
    api.kubelacave.kube     CNAME   master0.kubelacave.kube.lacave.info.
    api-int.kubelacave.kube CNAME   master0.kubelacave.kube.lacave.info.

Ne pas oublier d'incrémenter le numéro de série dans le fichier de zone:

lacave.info                     IN SOA  dns1.lacave.info. root.localhost.lacave.info. (
                                2021050602 ; serial

Recharger le fichier de zone:

    sudo systemctl reload bind9

On peut accéder à la console: https://console-openshift-console.apps.kubelacave.kube.lacave.info
Le mot de passe de l'utilisateur kubeadmin est dans le fichier ~/okd/manifest/auth/kubeadmin-password

# Configration du cluster
Un fois le cluster installé, il y a quelques composants complémentaires à y ajouter avant de pouvoir installer des applications.

## Certificats
Le cluster génère lui même ses certificats pour les routes propagés par le ingress-router.
Pour faire confiance à ces certificats, on doit ajouter le certificat de l'autorité de certification utilisé par le router.
Pour extraire le certificat, lancer la commande suivante:

    kubectl get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > router-ca.pem

Le certificat est maintenant dans le fichier router-ca.pem.

Dans Firefox, on peut l'ajouter dans la liste des autorités de certification de confiance en allant dans les préférences.
Pour l'ajouter dans les certificats de confiance de votre machine Windows, utiliser la console des certificats.
Pour l'ajouter dans Ubuntu, faire les étapes suivantes:

    Copier le fichier dans le répertoire /usr/local/share/ca-certificates/
        sudo cp router-ca.pem /usr/local/share/ca-certificates/router-ca.crt
    Importer le certificat:
        sudo update-ca-certificates

    
## Gestion des noeuds

### Ajouter des noeuds de travail (worker nodes)
Source: https://docs.okd.io/latest/post_installation_configuration/node-tasks.html
Lors de la création des fichier ignition, un fichier worker.ign a été créé.
On va l'utiliser avec PXE pour démarrer l'installation des nouveaux noeuds.

La première étape est de configurer les fichiers PXE pour les nouveaux noeuds. Par exemple, la l'adresse MAC de la nouvelle machine kube05 est aa:aa:aa:aa:ad, on doit créer le fichier suivant:

On doit ensuite copier le fichier worker.ign vers /var/www/html/okd/kube05.ign et y insérer les lignes suivantes:

Répéter ces étapes pour chacun des noeuds à ajouter.

Un fois les noeuds démarré, l'installation de fait automatiquement.

Pour accepter les nouveaux noeuds dans le cluster, on doit accepter les requètes de signature de certifcats.
Premièrement, on peut obtenir la liste des requête avec la commande suivante:

    oc get csr

On accepte les requêtes avec la commande suivantes:

    oc adm certificate approve id_du_certificat_obtenu_par_la_commande_precedente

Un fois le traitement fait, on peut vérifier que les nouveaux noeuds ont bien été ajoutés au cluster:

    oc get nodes
    NAME     STATUS   ROLES           AGE     VERSION
    kube01   Ready    master,worker   4d17h   v1.20.0+7d0a2b2-1058
    kube02   Ready    master,worker   4d17h   v1.20.0+7d0a2b2-1058
    kube03   Ready    master,worker   4d17h   v1.20.0+7d0a2b2-1058
    kube05   Ready    worker          16h     v1.20.0+7d0a2b2-1058
    kube06   Ready    worker          16h     v1.20.0+7d0a2b2-1058
    kube07   Ready    worker          15h     v1.20.0+7d0a2b2-1058


## Authentification au registres d'images

On utilise les crédentiels qu'on a dans notre fichier .docker/config.json
https://docs.openshift.com/container-platform/4.8/openshift_images/managing_images/using-image-pull-secrets.html

    oc create secret generic docker-secret --from-file=.dockerconfigjson=/home/felip/.docker/config.json --type=kubernetes.io/dockerconfigjson
    oc secrets link default docker-secret --for=pull

Pour ajouter le secret à la config globale:
Obtenir la liste des secret de la config:

    oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > globalpullsecret

Ajouter le crédentiel docker.io au fichier globalpullsecret

    oc registry login --registry=docker.io --auth-basic="username:password" --to=globalpullsecret

Mettre à jour la configuration globale:

    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=globalpullsecret

## Stockage

Chaque noeuds possède du stockage local. Pour faciliter son utilisation, on installe des approvisionneurs de stockage.

### OpenEBS
Le stockage local des noeuds est géré avec OpenEBS: https://docs.openebs.io/docs.
Ce type de stockage n'est, en général, pas redondant. Les StatefulSet qui utilisent ce stockage doivent donc être redontant.

### Création des groupes de volumes pour OpenEBS

Dans cette preuve de concept, nous utilisons LVM pour gérer les disques qui hébergent les données du cluster.

La première étape est de créer un groupe de disque virtuel avec les disques suppémentaires. Dans les machines de la preuves de concept, chaque noeud est équipé d'un deuxième disque à plateau SATA /dev/sdb. Pour ce type de disque, on créé le groupe de disque virtuel slowvg.

    ssh -i keys/kubelacave-key core@kube01 "sudo vgcreate slowvg /dev/sdb"
    ssh -i keys/kubelacave-key core@kube02 "sudo vgcreate slowvg /dev/sdb"
    ssh -i keys/kubelacave-key core@kube03 "sudo vgcreate slowvg /dev/sdb"
    ssh -i keys/kubelacave-key core@kube05 "sudo vgcreate slowvg /dev/sdb"
    ssh -i keys/kubelacave-key core@kube06 "sudo vgcreate slowvg /dev/sdb"
    ssh -i keys/kubelacave-key core@kube07 "sudo vgcreate slowvg /dev/sdb"

Les noeuds kube05, kube06 et kube07 ont des disques SSD dans /dev/sdc Pour les disques SSD:

    ssh -i keys/kubelacave-key core@kube05 "sudo vgcreate fastvg /dev/sdc"
    ssh -i keys/kubelacave-key core@kube06 "sudo vgcreate fastvg /dev/sdc"
    ssh -i keys/kubelacave-key core@kube07 "sudo vgcreate fastvg /dev/sdc"

#### Installation
La meilleure manière que j.ai trouvé de l'installer c'est en utilisant les chartes YAML:

Pour installer l'opérateur OpenEBS:

    kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

J'ai utilisé l'installation par défaut le l'opérateur. Tout est déployé dans le namespace openebs.
Les approvisionneurs installés sont:

    - Device
    - Host path
    - Jiva

L'installation créé par défaut 4 classes de stockage:

    kubectl get storageclass
    NAME                        PROVISIONER                                                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
    openebs-device              openebs.io/local                                           Delete          WaitForFirstConsumer   false                  98d
    openebs-hostpath            openebs.io/local                                           Delete          WaitForFirstConsumer   false                  98d
    openebs-jiva-default        openebs.io/provisioner-iscsi                               Delete          Immediate              false                  98d
    openebs-snapshot-promoter   volumesnapshot.external-storage.k8s.io/snapshot-promoter   Delete          Immediate 

La classe openebs-hostpath peut être utilisée telle quelle. Les données sont alors déposé dans le répertoire /var/openebs/local du rootvg des noeuds.

Installer lvm-localpv

    kubectl apply -f https://openebs.github.io/charts/lvm-operator.yaml
    
L'opérateur lvm s'installe dans le namespace kube-system

La documentation pour LVM: https://github.com/openebs/lvm-localpv

On créé ensuite 2 classes de stockage pour gérer le stockage rapide de type SSD et lent de type SATA de amnière différente.
Voici les classes à créer

    openebs-lvm-localpv-fast: openebs/storage-class-fast.yaml
    openebs-lvm-localpv-slow: openebs/storage-class-slow.yaml

Pour les appliquer:

    kubectl create -f openebs/storage-class-fast.yaml
    kubectl create -f openebs/storage-class-slow.yaml

Pour tester, on peut déployer les pods exemples inclus dans le projetL

    kubectl create -f openebs/exemple-stockage.yaml

On peut les supprimer avec la commande suivante:

    kubectl delete -f openebs/exemple-stockage.yaml

Ca peut prendre quelques secondes/minutes, le temps que le provisioner retire les volumes logiques de sur les hôtes.

Dans mon cas, j'ai du faire les étapes décrites dans l'issue https://github.com/openebs/openebs/issues/3046

### Minio
On a pas utilisé minio dans la POC

Installer le gestionnaire de plugin krew pour kubectl:

    (set -x; cd "$(mktemp -d)" &&   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&   tar zxvf krew.tar.gz &&   KREW=./krew-"${OS}_${ARCH}" &&   "$KREW" install krew;)

Installer le plugin minio

    kubectl krew install minio

Créer le projet minio-operator

    oc new-project minio-operator --description="Minio Storage Operator" --display-name="Minio Operator"

Configurer la sécurité: https://github.com/minio/operator/issues/289

    oc adm policy add-scc-to-user anyuid -z minio-operator -n minio-operator

Déployer l'opérateur:

    kubectl minio init -n minio-operator

Accéder à la console:

   kubectl minio proxy -n minio-operator

L'adresse de la console est affiché lors du lancement du proxy.

Créer la classe de stockage et les volumnes persistants

    kubectl apply -f minio/miniostorage.yaml

Création d'un tenant

    Créer le namespace pour le tenant:
        oc new-project minio-tenant --description="Minio Storage Tenant" --display-name="Minio Tenant"
    Créer le Tenant
        kubectl minio tenant create minio-tenant --servers 3 --volumes 6 --capacity 600Gi --storage-class minio-local-storage --namespace minio-tenant
    Créer un proxy pour accéder à la console du tenant:
        kubectl port-forward svc/minio-tenant-console -n minio-tenant 9443:9443
    On peut accéder à la console par l'URL https://localhost:9443
    Obtenir le crédentiel pour s'authentifier à la console:
        echo $(oc get secret minio-tenant-console-secret -n minio-tenant -o jsonpath='{.data.CONSOLE_ACCESS_KEY}' | base64 -d):$(oc get secret minio-tenant-console-secret -n minio-tenant -o jsonpath='{.data.CONSOLE_SECRET_KEY}' | base64 -d)

## Activer le registre d'image

## Journalisation

## Mise à jour du cluster
Voici les étapes pour la mise à jour du cluster: https://docs.okd.io/latest/updating/updating-cluster-cli.html

J'ai été obligé de modifier la confdiguration de l'opérateur de mises à jour avec la commande suivante: https://gitmemory.com/issue/openshift/okd/674/857717204

    oc patch clusterversion/version --patch '{"spec":{"upstream":"https://amd64.origin.releases.ci.openshift.org/graph"}}' --type=merge


Obtenir la liste des mises à jour disponible pour le cluster

    oc adm upgrade
    Cluster version is 4.7.0-0.okd-2021-06-04-191031

    Updates:

    VERSION                       IMAGE
    4.7.0-0.okd-2021-06-13-090745 registry.ci.openshift.org/origin/release@sha256:ab372d72a365b970193bc3369f6eecfd3d63a5d71c24edd263743b263c053155
    4.7.0-0.okd-2021-06-19-191547 registry.ci.openshift.org/origin/release@sha256:a6a71ae89dc9e171fecc2fb93d6a02f9bdd720cd4ca93c1de0b0c5575c12c907

Lancer la mise à jour:

    oc adm upgrade --to-latest=true
    Updating to latest version 4.7.0-0.okd-2021-06-19-191547

    {
    "channel": "stable-4",
    "clusterID": "76d5234b-76bc-4964-8c88-35b54b21b36e",
    "desiredUpdate": {
        "force": false,
        "image": "registry.ci.openshift.org/origin/release@sha256:a6a71ae89dc9e171fecc2fb93d6a02f9bdd720cd4ca93c1de0b0c5575c12c907",
        "version": "4.7.0-0.okd-2021-06-19-191547"
    },
    "upstream": "https://amd64.origin.releases.ci.openshift.org/graph"
    }

Vérifier la progression de la mise à jour:

    oc get clusterversion
    NAME      VERSION                         AVAILABLE   PROGRESSING   SINCE   STATUS
    version   4.7.0-0.okd-2021-06-04-191031   True        True          19m     Working towards 4.7.0-0.okd-2021-06-19-191547: 115 of 670 done (17% complete)

# Gestion des bases de données

On va utiliser quelques outils pour faciliter les gestion des instances de bases de données.

## Stackgres

Stackgres est un opérateur qui permet de créer des cluster de bases de données.
Ne semble pas bien fonctionner sous OKD/Openshfit

Pour installer l'opérateur:

    kubectl apply -f 'https://sgres.io/install?namespace=stackgres&adminui-service-type=LoadBalancer&grafana-autoEmbed=true'


Modifier la policy pour permettre aux pods de spécifier des id de groupe et de user standards:
    oc adm policy add-scc-to-user nonroot -z stackgres-operator -n stackgres
    oc adm policy add-scc-to-user nonroot -z stackgres-restapi -n stackgres
    oc adm policy add-scc-to-user nonroot -z stackgres-operator-init -n stackgres

On peut déployer le cluster exemple:
    kubectl create -f stackgres/exemple-cluster-fast.yaml 
    oc adm policy add-scc-to-user nonroot -z simple-pg-cluster-fast-patroni -n stackgres

## Zalando

Un autre opérateur Postgres:

https://github.com/zalando/postgres-operator/blob/master/docs/quickstart.md

Installation:

    Faire un clone du repository
        git clone https://github.com/zalando/postgres-operator.git
    Créer le namespace
        kubectl create namespace postgres-operator
    Installer l'opérateur et le UI
        cd postgres-operator
        helm install postgres-operator ./charts/postgres-operator --set configKubernetes.enable_pod_antiaffinity=true -n postgres-operator
        helm install postgres-operator-ui ./charts/postgres-operator-ui -n postgres-operator
    Ajuster les policy pour les UID des utilisateurs et GID des groupes pour les pods privilégiés
        oc adm policy add-scc-to-user nonroot -z builder -n postgres-operator
        oc adm policy add-scc-to-user nonroot -z default -n postgres-operator
        oc adm policy add-scc-to-user nonroot -z deployer -n postgres-operator
        oc adm policy add-scc-to-user nonroot -z postgres-operator -n postgres-operator
        oc adm policy add-scc-to-user nonroot -z postgres-operator-ui -n postgres-operator
    Ajouter les droits cluster admin au compte de service postgres-pod
        kubectl create -f zalando/postgres-pod-cluster-admin.yaml

On peut créer un cluster de test avec le manifest suivant:
    
    kubectl create -f zalando/minimal-postgres-manifest.yaml

Patcher le service pour lui ajouter un pod selector:

    kubectl patch service acid-minimal-cluster -n default -p '{"spec":{"selector":{"application":"spilo","cluster-name":"acid-minimal-cluster","spilo-role":"master"}}}'
    
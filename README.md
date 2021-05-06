# Installation OKD sur BareMetal

On utilise Fedora CoreOS comme système d'exploitation pour installer OKD sur des machines physiques.

Pour déployer un cluster a trois noeuds on a besoin de 4 machines:

    kube01: master0
    kube02: master1
    kube03: master2
    kube04: bootstrap

La machine bootstrap est temporaire, c'est celle qui va déployer le cluster sur les autres noeuds.

Voici les infpormations pour ce cluster:

    Zone DNS pour le cluster: kube.lacave.info
    Nom du cluster: kubelacave
## PXE Boot
Il est possible de provisionner les hôtes en utilisant pxelinux au lieu de l'image ISO. Cette section décrit comment le faire avec isc-dhcp-server, tftpd-hpa et pcelinux sous Ubuntu 20.04.

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

## Préparation du DNS

Dans notre installation, Un serveur DNS bind est installé sur le serveur de provisionning.
Le fichier de zone pour lacave.info est /etc/bind/lacave.info.db
La zone DNS lacave.info sera utilisé pour le cluster.

La procédure d'installation de bind et de la création de la zone n'est pas encore incluse dans ce document: A venir.

On a besoin des entrés suivantes:
$ORIGIN lacave.info.
$TTL 3600       ; 1 hour
dns1                    A       192.168.1.10

kube01                  A       192.168.1.21
master0.kubelacave.kube CNAME   kube01.lacave.info.
kube02                  A       192.168.1.22
master1.kubelacave.kube CNAME   kube02.lacave.info.
kube03                  A       192.168.1.23
master2.kubelacave.kube CNAME   kube03.lacave.info.
kube04                  A       192.168.1.24
bootstrap.kubelacave.kube       CNAME   kube04.lacave.info.

kube                    CNAME   bootstrap.kubelacave.kube.lacave.info.
api.kubelacave.kube     CNAME   bootstrap.kubelacave.kube.lacave.info.
api-int.kubelacave.kube CNAME   bootstrap.kubelacave.kube.lacave.info.
helper.kubelacave.kube  CNAME   bootstrap.kubelacave.kube.lacave.info.
*.kube                  CNAME   kube.lacave.info.
*.kubelacave.kube       CNAME   kube.lacave.info.

Les entrés helper.kubelacave.kube, api.kubelacave.kube et api.kubelacave.kube doivent résoudre vers l'adresse du bootstrap lors de l'installation initiale.
Un fois le cluster démarré, on doit changer la destination pour master0.kubelacave.kube.lacave.info.
Les entrés devront alors être modifiées pour:

    api.kubelacave.kube     CNAME   master0.kubelacave.kube.lacave.info.
    api-int.kubelacave.kube CNAME   master0.kubelacave.kube.lacave.info.
    kube                    CNAME   master1.kubelacave.kube.lacave.info.

Cette étape est néceessaire parce qu'on a pas de load balancer. 

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
        - path: /etc/NetworkManager/system-connections/enp3s0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=enp3s0

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
    wget https://github.com/openshift/okd/releases/download/4.7.0-0.okd-2021-04-24-103438/openshift-client-linux-4.7.0-0.okd-2021-04-24-103438.tar.gz
    tar -zxvf openshift-client-linux-4.7.0-0.okd-2021-04-24-103438.tar.gz
    sudo cp oc /usr/local/bin

Install:

    cd ~/okd
    wget https://github.com/openshift/okd/releases/download/4.7.0-0.okd-2021-04-24-103438/openshift-install-linux-4.7.0-0.okd-2021-04-24-103438.tar.gz
    tar -zxvf openshift-install-linux-4.7.0-0.okd-2021-04-24-103438.tar.gz


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

Dans Firefox, on peut l'ajouter dans la liste des autorités de certificaiton de confiance en allant dans les préférences.
Pour l'ajouter dans les certificats de confiance de votre machine Windows, utiliser la console des certificats.
Pour l'ajouter dans Ubuntu, faire els étapes suivantes:

    Copier le fichier dans le répertoire /usr/local/share/ca-certificates/
        sudo cp router-ca.pem /usr/local/share/ca-certificates/router-ca.crt
    Importer le certificat:
        sudo update-ca-certificates

    
## Stockage

## Activer le registre d'image

## Journalisation

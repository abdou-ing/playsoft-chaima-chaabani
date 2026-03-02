
import os
import requests

# ===========================
# CHARGER TOKENS DEPUIS .env
# ===========================
HETZNER_TOKEN = os.getenv('HETZNER_TOKEN')
JUMPSERVER_URL = os.getenv('JUMPSERVER_URL')
JUMPSERVER_TOKEN = os.getenv('JUMPSERVER_TOKEN')

# Vérifier que les tokens sont configurés
if not HETZNER_TOKEN:
    print("ERREUR: HETZNER_TOKEN non configuré")
    print("   Exécutez: source .env")
    exit(1)
if not JUMPSERVER_URL:
    print("ERREUR: JUMPSERVER_URL non configuré")
    print("   Exécutez: source .env")
    exit(1)
if not JUMPSERVER_TOKEN:
    print("ERREUR: JUMPSERVER_TOKEN non configuré")
    print("   Exécutez: source .env")
    exit(1)

# ===========================
# SCRIPT
# ===========================

print("Connexion à Hetzner...")
servers = []
page = 1
per_page = 50
while True:
    response = requests.get(
        "https://api.hetzner.cloud/v1/servers",
        headers={"Authorization": f"Bearer {HETZNER_TOKEN}"},
        params={"page": page, "per_page": per_page},
        timeout=30,
    )
    if response.status_code != 200:
        print(f"ERREUR: Hetzner API {response.status_code}")
        print(response.text)
        exit(1)

    payload = response.json()
    servers.extend(payload.get("servers", []))
    if len(payload.get("servers", [])) < per_page:
        break
    page += 1

print(f"✓ {len(servers)} serveurs trouvés\n")

print("Vérification dans JumpServer...\n")

for server in servers:
    server_name = server.get("name")
    public_net = server.get("public_net") or {}
    public_ipv4 = public_net.get("ipv4") or {}
    server_ip = public_ipv4.get("ip")

    if not server_ip:
        private_nets = server.get("private_net", [])
        for private_net in private_nets:
            private_ip = private_net.get("ip")
            if private_ip:
                server_ip = private_ip
                break

    if not server_ip:
        print(f"⚠ {server_name}: Aucune IP trouvée, ignoré")
        continue

    # Vérifier si le serveur existe dans JumpServer
    response = requests.get(
        f"{JUMPSERVER_URL}/api/v1/assets/hosts/?name={server_name}",
        headers={"Authorization": f"Bearer {JUMPSERVER_TOKEN}"}
    )

    existing_assets = response.json() if response.status_code == 200 else []
    
    # Si le serveur n'existe pas dans JumpServer
    if len(existing_assets) == 0:
        print(f"❌ {server_name} ({server_ip}): NON présent dans JumpServer")
        
        # Ajouter automatiquement le serveur (créer un Host)
        result = requests.post(
            f"{JUMPSERVER_URL}/api/v1/assets/hosts/",
            json={
                "name": server_name,
                "address": server_ip,
                "platform": 1  # 1 = Unix/Linux
            },
            headers={
                "Authorization": f"Bearer {JUMPSERVER_TOKEN}",
                "Content-Type": "application/json"
            }
        )

        if result.status_code in [200, 201]:
            print(f"✓ {server_name} ajouté à JumpServer\n")
        else:
            print(f"✗ Erreur pour {server_name}: {result.status_code}\n")
    else:
        print(f"✓ {server_name} ({server_ip}): Déjà dans JumpServer\n")

print("✅ Synchronisation terminée")


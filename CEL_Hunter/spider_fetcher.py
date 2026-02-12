import requests
import os
import sys
import time
import json
import re
from pathlib import Path
from dotenv import load_dotenv

# --- Configuration ---
DEV_DIR = Path(__file__).parent
DOTENV_PATH = DEV_DIR / ".env"
load_dotenv(DOTENV_PATH)

def get_clean_env(key):
    val = os.getenv(key)
    return val.strip() if val else None

ETHERSCAN_KEY = get_clean_env("ETHERSCAN_API_KEY")
ANKR_KEY = get_clean_env("ANKR_API_KEY")
BASE_URL = "https://api.etherscan.io/v2/api?chainid=56"
# EIP-1967 Implementation Slot
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

IGNORE_ADDRS = [
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", # WBNB
    "0x10ed43c718714eb63d5aa57b78b54704e256024e", # Pancake Router
    "0x0000000000000000000000000000000000000000",
    "0x000000000000000000000000000000000000dead",
]

def get_implementation(proxy_address):
    """Queries Ankr RPC for the implementation address of a proxy."""
    if not ANKR_KEY: return None
    rpc_url = f"https://rpc.ankr.com/bsc/{ANKR_KEY}"
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_getStorageAt",
        "params": [proxy_address, IMPL_SLOT, "latest"]
    }
    try:
        r = requests.post(rpc_url, json=payload, timeout=10).json()
        res = r.get('result', "0x0")
        if res != "0x0000000000000000000000000000000000000000000000000000000000000000":
            return "0x" + res[-40:]
    except: pass
    return None

def fetch_source(address, save_path):
    url = f"{BASE_URL}&module=contract&action=getsourcecode&address={address}&apikey={ETHERSCAN_KEY}"
    try:
        r = requests.get(url, timeout=10).json()
        if r.get('status') == '1' and r.get('result'):
            res = r['result'][0]
            name = res.get('ContractName')
            code = res.get('SourceCode')
            if not name or not code: return None
            
            addr_path = save_path / f"{address}_{name}"
            addr_path.mkdir(parents=True, exist_ok=True)
            
            # MULTI-FILE DETECTION
            sources = None
            if code.startswith('{{'):
                try: sources = json.loads(code[1:-1]).get('sources', json.loads(code[1:-1]))
                except: pass
            elif code.startswith('{'):
                try: sources = json.loads(code).get('sources', json.loads(code))
                except: pass

            if sources:
                for f_path, content_obj in sources.items():
                    file_full_path = addr_path / f_path
                    file_full_path.parent.mkdir(parents=True, exist_ok=True)
                    content = content_obj.get('content', '') if isinstance(content_obj, dict) else content_obj
                    with open(file_full_path, "w", encoding="utf-8") as f:
                        f.write(content)
                return f"{name} ({len(sources)} files)"
            else:
                with open(addr_path / f"{name}.sol", "w", encoding="utf-8") as f:
                    f.write(code)
                return f"{name} (Single file)"
    except: pass
    return None

def scan_code_for_addresses(folder_path):
    found = set()
    addr_pattern = re.compile(r"0x[a-fA-F0-9]{40}")
    for root, _, files in os.walk(folder_path):
        for file in files:
            if file.endswith(".sol"):
                try:
                    with open(Path(root) / file, "r", encoding="utf-8") as f:
                        matches = addr_pattern.findall(f.read())
                        for a in matches:
                            if a.lower() not in IGNORE_ADDRS: found.add(a.lower())
                except: pass
    return list(found)

def crawl_ecosystem(token_address):
    token_address = token_address.lower()
    print(f"[*] 🕸  CEL MASTER SPIDER v1.6")
    print(f"[*] Analyzing: {token_address}")
    
    project_path = DEV_DIR / "projects" / f"eco_{token_address[:10]}"
    project_path.mkdir(parents=True, exist_ok=True)

    queue = [token_address]
    processed = set()
    
    while queue:
        addr = queue.pop(0)
        if addr in processed: continue
        processed.add(addr)

        print(f"  - Probing {addr}...", end="", flush=True)
        info = fetch_source(addr, project_path)
        
        if info:
            print(f" ✅ Saved: {info}")
            # Check if it's a proxy
            if "Proxy" in info:
                impl = get_implementation(addr)
                if impl:
                    print(f"    [!] Proxy detected! Found Implementation: {impl}")
                    queue.append(impl)
            
            # Scan code for more links (Depth 1)
            if addr == token_address:
                links = scan_code_for_addresses(project_path)
                for l in links:
                    if l not in processed: queue.append(l)
        else:
            print(" ❌ (Private/Unverified)")
        
        time.sleep(0.3)

    print(f"\n[🏁] ANALYSIS COMPLETE. Captured {len(os.listdir(project_path))} contracts.")
    print(f"    - Results: {project_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 spider_fetcher.py <address>")
        sys.exit(1)
    crawl_ecosystem(sys.argv[1])

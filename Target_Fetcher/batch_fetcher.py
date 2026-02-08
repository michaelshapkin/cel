import os
import csv
import time
import requests
import json
from pathlib import Path
from dotenv import load_dotenv

# Load env variables from current directory
load_dotenv()

ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY")
BSC_API_KEY = os.getenv("BSC_API_KEY")
BASE_API_KEY = os.getenv("BASE_API_KEY") or os.getenv("ETHERSCAN_API_KEY") # Try fallback

CHAIN_MAP = {
    "mainnet": "1",
    "bsc": "56",
    "base": "8453"
}

def fetch_source(address, chain_name, api_key):
    chain_id = CHAIN_MAP.get(chain_name)
    if not chain_id:
        return False, f"Unsupported chain: {chain_name}"
    
    # Etherscan V2 API endpoint
    url = f"https://api.etherscan.io/v2/api?chainid={chain_id}&module=contract&action=getsourcecode&address={address}&apikey={api_key}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        return False, f"Network error: {e}"

    if data.get('status') != '1':
        return False, f"API Error: {data.get('message')}"

    if not data.get('result') or not data.get('result')[0].get('SourceCode'):
        return False, "No source code found"

    result = data['result'][0]
    source_code = result['SourceCode']
    contract_name = result['ContractName']

    # Save to downloads/<chain>/<address>/<name>
    base_path = Path(f"downloads/{chain_name}/{address}/{contract_name}")
    base_path.mkdir(parents=True, exist_ok=True)

    if source_code.startswith('{{') and source_code.endswith('}}'):
        json_content = source_code[1:-1]
        try:
            source_data = json.loads(json_content)
            sources = source_data.get('sources', source_data) if isinstance(source_data, dict) else {}
            
            for file_path, content_obj in sources.items():
                full_path = base_path / file_path
                full_path.parent.mkdir(parents=True, exist_ok=True)
                content = content_obj['content'] if isinstance(content_obj, dict) else content_obj
                with open(full_path, "w", encoding="utf-8") as f:
                    f.write(content)
        except Exception as e:
            with open(base_path / f"{contract_name}_raw.json", "w") as f:
                f.write(source_code)
    else:
        with open(base_path / f"{contract_name}.sol", "w", encoding="utf-8") as f:
            f.write(source_code)
            
    return True, f"Saved to {base_path}"

def main():
    csv_path = Path("benchmark.csv")
    if not csv_path.exists():
        print(f"[!] {csv_path} not found!")
        return

    print(f"[*] Starting batch fetch from {csv_path}...")
    
    with open(csv_path, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            case_name = row['case_name']
            chain = row['chain'].replace('"', '').strip() # Clean chain name
            address = row['target_contract_address']
            
            # Select key
            if chain == "mainnet":
                api_key = ETHERSCAN_API_KEY
            elif chain == "bsc":
                api_key = BSC_API_KEY
            elif chain == "base":
                api_key = BASE_API_KEY
            else:
                print(f"[!] Unknown chain {chain}, skipping {case_name}")
                continue
            
            if not api_key:
                print(f"[!] Missing API key for {chain}, skipping {case_name}")
                continue

            print(f"[*] [{chain}] Fetching {case_name} ({address})...", end=" ", flush=True)
            
            # Simple check if already downloaded
            # (We check for the directory existence)
            # if os.path.exists(f"downloads/{chain}/{address}"):
            #     print("ALREADY EXISTS")
            #     continue

            success, msg = fetch_source(address, chain, api_key)
            
            if success:
                print("OK")
            else:
                print(f"FAILED: {msg}")
            
            time.sleep(0.3)

if __name__ == "__main__":
    main()
import os
import csv
import json
import time
import requests
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# --- Configuration ---
API_KEYS = {
    "mainnet": os.getenv("ETHERSCAN_API_KEY"),
    "bsc": os.getenv("BSC_API_KEY"),
    "base": os.getenv("BASE_API_KEY") or os.getenv("ETHERSCAN_API_KEY")
}

CHAIN_IDS = {
    "mainnet": "1",
    "bsc": "56",
    "base": "8453"
}

# Output directory mirroring Anthropic's structure
OUTPUT_DIR = Path("../Anthropic_Replication/workdir/etherscan-contracts")

def fetch_contract_data(address, chain, api_key):
    """Fetches source code and implementation address from Etherscan V2 API."""
    chain_id = CHAIN_IDS.get(chain)
    if not chain_id: return None, f"Unsupported chain: {chain}"

    url = "https://api.etherscan.io/v2/api"
    params = {
        "chainid": chain_id,
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": api_key
    }

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        if data.get("status") != "1" or not data.get("result"):
            return None, f"API Error: {data.get('message')}"
        return data["result"][0], None
    except Exception as e:
        return None, f"Network error: {str(e)}"

def save_source_code(case_name, address, source_data, output_base):
    """
    Parses and saves source code to a nested case-specific directory.
    Structure: etherscan-contracts/<case_name>/<address>/<ContractName>/...
    """
    contract_name = source_data.get("ContractName", "Unknown")
    source_code = source_data.get("SourceCode", "")
    
    # Nested structure for better organization
    target_dir = output_base / case_name / address / contract_name
    target_dir.mkdir(parents=True, exist_ok=True)

    if source_code.startswith("{{") and source_code.endswith("}}"):
        try:
            json_content = source_code[1:-1]
            parsed_json = json.loads(json_content)
            sources = parsed_json.get("sources", parsed_json) if isinstance(parsed_json, dict) else {}
            
            for file_path, content_obj in sources.items():
                clean_path = file_path.lstrip('/')
                full_path = target_dir / clean_path
                full_path.parent.mkdir(parents=True, exist_ok=True)
                
                content = content_obj.get("content") if isinstance(content_obj, dict) else content_obj
                if content:
                    with open(full_path, "w", encoding="utf-8") as f:
                        f.write(content)
            return True, f"Saved multi-part to {target_dir}"
        except Exception as e:
            with open(target_dir / f"{contract_name}_raw.json", "w", encoding="utf-8") as f:
                f.write(source_code)
            return True, f"Saved raw JSON (parsing failed: {str(e)})"
    else:
        file_path = target_dir / f"{contract_name}.sol"
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(source_code)
        return True, f"Saved single file to {file_path}"

def process_contract(case_name, address, chain):
    """Orchestrates the download of the proxy and its implementation."""
    chain_clean = chain.replace('"', '').strip()
    case_clean = case_name.replace('"', '').strip()
    api_key = API_KEYS.get(chain_clean)
    
    if not api_key:
        print(f"[!] Skipping {case_clean}: Missing API Key for {chain_clean}")
        return

    # Check if case folder already exists to avoid redundant work
    case_path = OUTPUT_DIR / case_clean
    if case_path.exists():
        print(f"[*] Case {case_clean} already exists. Skipping.")
        return

    print(f"[*] Processing Case: {case_clean} ({address}) on {chain_clean}...")

    # 1. Fetch Target (Proxy)
    data, error = fetch_contract_data(address, chain_clean, api_key)
    if error:
        print(f"    [!] Failed to fetch target: {error}")
        return

    save_success, save_msg = save_source_code(case_clean, address, data, OUTPUT_DIR)
    
    # 2. Check for Implementation
    impl_address = data.get("Implementation")
    if impl_address and impl_address != "" and impl_address != "0x0000000000000000000000000000000000000000":
        if impl_address.lower() != address.lower():
            print(f"    [*] Proxy detected. Fetching implementation: {impl_address}...")
            impl_data, impl_error = fetch_contract_data(impl_address, chain_clean, api_key)
            if not impl_error:
                save_source_code(case_clean, impl_address, impl_data, OUTPUT_DIR)
    
    time.sleep(0.3)

def main():
    csv_path = Path("benchmark.csv")
    if not csv_path.exists():
        print("[!] benchmark.csv not found.")
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    with open(csv_path, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            process_contract(row['case_name'], row['target_contract_address'], row['chain'])

if __name__ == "__main__":
    main()

import os
import requests
import json
import sys
from pathlib import Path

def fetch_source(address, api_key, chain_id):
    # Etherscan V2 API endpoint (works for BSC with chainid)
    # Using the new V2 URL structure
    url = f"https://api.etherscan.io/v2/api?chainid={chain_id}&module=contract&action=getsourcecode&address={address}&apikey={api_key}"
    
    print(f"[*] Fetching source for address {address} (ChainID: {chain_id}) via V2 API...")
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(f"[!] Network error: {e}")
        return

    # In V2, the response structure is similar but let's be safe
    if data.get('status') != '1':
        print(f"[!] API Error: {data.get('message')} (Result: {data.get('result')})")
        return

    if not data.get('result') or not data.get('result')[0].get('SourceCode'):
        print("[!] No source code found for this address.")
        return

    result = data['result'][0]
    source_code = result['SourceCode']
    contract_name = result['ContractName']

    base_path = Path(f"downloads/{address}/{contract_name}")
    base_path.mkdir(parents=True, exist_ok=True)

    # Parsing the source code format
    if source_code.startswith('{{') and source_code.endswith('}}'):
        print("[+] Multi-file structure detected. Parsing...")
        json_content = source_code[1:-1]
        try:
            source_data = json.loads(json_content)
            
            # Handle standard JSON input format
            if isinstance(source_data, dict) and 'sources' in source_data:
                sources = source_data['sources']
            elif isinstance(source_data, dict):
                sources = source_data
            else:
                sources = {}

            for file_path, content_obj in sources.items():
                full_path = base_path / file_path
                full_path.parent.mkdir(parents=True, exist_ok=True)
                
                content = content_obj['content'] if isinstance(content_obj, dict) else content_obj
                with open(full_path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"  - Saved: {file_path}")
                
        except Exception as e:
            print(f"[!] Error parsing JSON: {e}")
            with open(base_path / f"{contract_name}_raw.json", "w") as f:
                f.write(source_code)
    else:
        print("[+] Single file detected.")
        with open(base_path / f"{contract_name}.sol", "w", encoding="utf-8") as f:
            f.write(source_code)
        print(f"  - Saved: {contract_name}.sol")

    print(f"\n[OK] All files saved to: {base_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 fetcher.py <contract_address>")
        sys.exit(1)

    api_key = None
    chain_id = "56" # Default to BSC
    
    if os.path.exists(".env"):
        with open(".env", "r") as f:
            for line in f:
                if line.strip().startswith("BSC_API_KEY="):
                    api_key = line.split("=")[1].strip()
                if line.strip().startswith("CHAIN_ID="):
                    chain_id = line.split("=")[1].strip()
    
    if not api_key or "YOUR_API_KEY" in api_key:
        print("[!] Please set your BSC_API_KEY in Target_Fetcher/.env file")
        sys.exit(1)

    fetch_source(sys.argv[1], api_key, chain_id)

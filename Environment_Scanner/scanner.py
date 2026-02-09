import os
import requests
import json
from web3 import Web3
from dotenv import load_dotenv

load_dotenv()
BSC_API_KEY = os.getenv("BSC_API_KEY")
ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY")
RPC_URL = "http://127.0.0.1:8545"

IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

def get_abi(address, chain_id):
    api_key = ETHERSCAN_API_KEY if chain_id == "1" else BSC_API_KEY
    url = f"https://api.etherscan.io/v2/api?chainid={chain_id}&module=contract&action=getabi&address={address}&apikey={api_key}"
    try:
        response = requests.get(url)
        data = response.json()
        if data['status'] == '1':
            return json.loads(data['result'])
    except Exception as e:
        print(f"Error fetching ABI: {e}")
    return None

def get_implementation(w3, proxy_address):
    impl = w3.eth.get_storage_at(proxy_address, IMPLEMENTATION_SLOT)
    impl_address = "0x" + impl[-20:].hex()
    if impl_address != "0x0000000000000000000000000000000000000000":
        return w3.to_checksum_address(impl_address)
    
    return None

def scan(address, chain_id="56"):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print("Error: Could not connect to Anvil")
        return

    target_addr = w3.to_checksum_address(address)
    
    impl_addr = get_implementation(w3, target_addr)
    if impl_addr:
        print(f"[*] Proxy detected! Implementation at: {impl_addr}")
        abi_addr = impl_addr
    else:
        abi_addr = target_addr

    abi = get_abi(abi_addr, chain_id)
    if not abi:
        print("Error: Could not fetch ABI")
        return

    contract = w3.eth.contract(address=target_addr, abi=abi)
    
    print(f"### Key Contract State Variables for {address}")
    
    for item in abi:
        if item.get('type') == 'function' and item.get('stateMutability') in ['view', 'pure']:
            if len(item.get('inputs', [])) == 0:
                name = item['name']
                try:
                    result = getattr(contract.functions, name)().call()
                    output_type = item['outputs'][0]['type'] if item.get('outputs') else "tuple"
                    
                    if isinstance(result, bytes):
                        result = "0x" + result.hex()
                    
                    print(f"- name={name} value={result} type={output_type})")
                except:
                    continue

if __name__ == "__main__":
    import sys
    target = sys.argv[1] if len(sys.argv) > 1 else "0xd511096a73292a7419a94354d4c1c73e8a3cd851"
    scan(target)
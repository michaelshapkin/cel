import requests
import os
import csv
import time
import unicodedata
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

# --- Configuration ---
DEV_DIR = Path(__file__).parent
DOTENV_PATH = DEV_DIR / ".env"
TARGETS_FILE = DEV_DIR / "targets.csv"

load_dotenv(DOTENV_PATH)

def get_clean_env(key):
    val = os.getenv(key)
    return val.strip() if val else None

ETHERSCAN_KEY = get_clean_env("ETHERSCAN_API_KEY")

# Blacklist of major/system tokens (not interesting for research)
BLACKLIST = [
    "0x0000000000000000000000000000000000000000", # Native BNB
    "0x55d398326f99059ff775485246999027b3197955", # USDT
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", # USDC
    "0xe9e7cea3dedca5984780bafc599add087d56", # BUSD
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", # WBNB
    "0x2170ed0880ac9a755fd29b2688956bd959f933f8", # ETH
    "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c", # BTCB
    "0x570a5d26f7765ecb712c0924e4de545b89fd43df", # SOL
    "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82", # CAKE
    "0xcae117ca6bc8a341d2e7207f30e180f0e5618b9d"  # ARK
]

def get_visual_width(s):
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in s)

def pad_string(s, width):
    v_width = get_visual_width(s)
    return s + " " * (width - v_width)

def check_verification(address):
    if not ETHERSCAN_KEY: return False
    url = f"https://api.etherscan.io/v2/api?chainid=56&module=contract&action=getsourcecode&address={address}&apikey={ETHERSCAN_KEY}"
    try:
        r = requests.get(url, timeout=10).json()
        if r.get('status') == '1' and r.get('result') and r['result'][0].get('SourceCode'):
            return True
    except: pass
    return False

def format_age(created_at):
    try:
        dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        delta = datetime.now(dt.tzinfo) - dt
        hours = delta.total_seconds() / 3600
        if hours < 24: return f"{int(hours)}h"
        return f"{int(hours/24)}d"
    except: return "???"

def hunt(pages=15):
    W_SYM = 22
    W_ADDR = 44
    W_LIQ = 15
    W_AGE = 6

    print(f"\n" + "="*115)
    print(f"🛡  CEL ANALYZER v2.7 | SECURITY AUDIT SCOPING")
    print(f"Initial Universe: {pages} Pages (~{pages*20} Raw Asset Pools) on BSC Network")
    print(f"Source: GeckoTerminal Trending + Etherscan V2 Multi-Chain API")
    print("="*115 + "\n")
    
    qualified = []
    total_liquidity = 0.0
    processed_addresses = set()

    print(f"  {pad_string('SYMBOL', W_SYM)} | {pad_string('AGE', W_AGE)} | {pad_string('CONTRACT ADDRESS', W_ADDR)} | {pad_string('LIQUIDITY', W_LIQ)} | VERIFICATION")
    print(f"  {'-'*(W_SYM)} | {'-'*W_AGE} | {'-'*W_ADDR} | {'-'*W_LIQ} | {'-'*30}")

    for page in range(1, pages + 1):
        api_url = f"https://api.geckoterminal.com/api/v2/networks/bsc/pools?include=base_token&page={page}"
        try:
            response = requests.get(api_url, timeout=15).json()
            pools = response.get('data', [])
            included = response.get('included', [])
            token_map = {t['id'].split('_')[1]: t['attributes'] for t in included if t['type'] == 'token'}
        except: continue

        if not pools: break

        for p in pools:
            base_token_addr = p['relationships']['base_token']['data']['id'].split('_')[1].lower()
            if base_token_addr in processed_addresses or base_token_addr in BLACKLIST: continue
            token_info = token_map.get(base_token_addr)
            if not token_info: continue
            
            reserve = float(p['attributes'].get('reserve_in_usd') or 0)
            if reserve < 1000: continue 

            if check_verification(base_token_addr):
                symbol = token_info['symbol'][:W_SYM-2]
                age = format_age(p['attributes'].get('pool_created_at', ''))
                liq_display = f"${reserve:,.0f}"
                
                print(f"  {pad_string(symbol, W_SYM)} | {age:<6} | {base_token_addr:<44} | {liq_display:<15} | ✅ [Source Code Verified on Explorer]")
                
                qualified.append({
                    "name": token_info['name'],
                    "symbol": token_info['symbol'],
                    "address": base_token_addr,
                    "liquidity": reserve,
                    "age": age,
                    "pair": p['attributes'].get('address')
                })
                total_liquidity += reserve
                processed_addresses.add(base_token_addr)
            
            time.sleep(0.1)

    if qualified:
        qualified.sort(key=lambda x: x['liquidity'], reverse=True)
        with open(TARGETS_FILE, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["name", "symbol", "address", "liquidity", "age", "pair"])
            writer.writeheader()
            writer.writerows(qualified)
        
        print("\n" + "="*115)
        print(f"🏁 AUDIT SCOPING COMPLETE")
        print(f"Summary: From {pages*20} raw pools, {len(qualified)} assets were qualified for security research.")
        print(f"💰 Total Aggregate Liquidity of Qualified Assets: ${total_liquidity:,.2f} USD")
        print("="*115)
    else:
        print("\n[!] No verified assets qualified matching the criteria.")

if __name__ == "__main__":
    hunt(pages=15)

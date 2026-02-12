# CEL Hunter – Asset Discovery & Ecosystem Recon

**CEL Hunter** is the reconnaissance module of the CEL infrastructure. It automates the discovery of high-value targets and performs deep recursive fetching of smart contract ecosystems to prepare them for security analysis.

---

## 🔍 Overview

Before an exploit can be developed in the **Exploit Laboratory**, a target must be identified and its code dependencies mapped. CEL Hunter bridges the gap between raw blockchain noise and structured research data.

### Key Capabilities
- **Trending Discovery**: Identifies active, liquid assets on the BNB Smart Chain (BSC) via GeckoTerminal.
- **Verification Filtering**: Automatically skips unverified or private contracts, focusing only on auditable code.
- **Recursive Ecosystem Spiders**: Crawls a token's source code to find linked contracts (e.g., Vaults, Staking, MasterChefs) and fetches them all.
- **Proxy Resolution**: Detects EIP-1967 proxy patterns and automatically pulls implementation logic from the blockchain state.

---

## 🏗️ Components

### 1. `hunter.py` (Scoping Tool)
Scans the "universe" of active trading pairs to find assets that match specific research criteria:
- **Min Liquidity**: Filters out low-liquidity "dust" pools.
- **Age Tracking**: Identifies how long an asset has been live.
- **Verification Check**: Uses Etherscan V2 API to ensure source code is available.
- **Output**: Generates `targets.csv` for batch processing.

### 2. `spider_fetcher.py` (Recon Spider)
A deep-analysis tool that builds a complete local copy of a project's ecosystem:
- **Recursive Fetching**: Parses downloaded Solidity files for other contract addresses and adds them to the crawl queue.
- **Proxy Detection**: Queries Ankr RPC for implementation slots to ensure you aren't just auditing a generic proxy shell.
- **Multi-File Support**: Handles JSON-formatted multi-file sources from Etherscan/BscScan.

---

## 🚀 Getting Started

### Prerequisites
- **Python 3.10+**
- **Etherscan/BscScan API Key** (V2 recommended)
- **Ankr API Key** (for RPC state checks)

### Installation
1. Navigate to the hunter directory:
   ```bash
   cd CEL_Hunter
   ```
2. Setup environment variables:
   ```bash
   cp .env.example .env
   # Ensure ETHERSCAN_API_KEY and ANKR_API_KEY are set
   ```

### Usage

#### Phase 1: Hunt for Targets
To find the top liquid assets on BSC:
```bash
python3 hunter.py
```
This will populate `targets.csv` with qualified addresses.

#### Phase 2: Spider an Ecosystem
To perform deep recon on a specific address:
```bash
python3 spider_fetcher.py <contract_address>
```
The ecosystem will be saved in the `projects/` directory, organized by implementation and linked contracts.

---

## 📊 Data Output
- `targets.csv`: A curated list of verified, liquid assets.
- `projects/`: Deep-recon folders containing full source code and dependency maps for each audited project.

---

*Part of the Continuous Execution Layer (CEL) suite by Michael Shapkin.*

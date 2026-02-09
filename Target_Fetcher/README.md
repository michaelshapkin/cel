# Target Fetcher

Automated tool for batch downloading smart contract source code across multiple EVM chains (Ethereum, BSC, Base) to facilitate security research and AI-agent benchmarking.

## Overview

This tool was developed to automate the preparation of target environments for smart contract vulnerability research. It is specifically designed to work with the **SCONE-bench** dataset, allowing for the rapid reconstruction of historical exploit scenarios.

### Key Features
- **Multi-Chain Support**: Seamlessly switches between Ethereum (Mainnet), Binance Smart Chain (BSC), and Base.
- **Proxy-Aware (Smart Fetching)**: Automatically detects proxy contracts via the `Implementation` field, resolves their logic addresses, and downloads both Proxy and Implementation source code.
- **Structured Workspace**: Organizes files into a case-specific hierarchy (`etherscan-contracts/<case_name>/<address>/...`) mirroring the environment provided to AI agents in **Anthropic's 2025 research**.
- **Etherscan V2 API Integration**: Utilizes the latest Etherscan V2 API architecture for unified cross-chain access.
- **Full Structure Reconstruction**: Automatically reconstructs original directory hierarchies for "Multi-part files" (e.g., `@openzeppelin/`, `contracts/`), ensuring imports work for local compilation.
- **Rate-Limit Aware**: Built-in delays to respect Free Tier API limits.

## Data Source

The targets are sourced from the [SCONE-bench (Smart CONtract Exploitation benchmark)](https://github.com/safety-research/SCONE-bench/) repository by Anthropic.

The included `benchmark.csv` contains metadata for 405 historically exploited contracts, including case names, addresses, and historical block numbers.

## Prerequisites

- Python 3.11+
- API Keys for [Etherscan](https://etherscan.io/), [BscScan](https://bscscan.com/), and [BaseScan](https://basescan.org/).

## Setup

1. Clone this repository.
2. Create a `.env` file in this directory with your API keys:
   ```env
   ETHERSCAN_API_KEY=your_key_here
   BSC_API_KEY=your_key_here
   BASE_API_KEY=your_key_here
   ```
3. Install dependencies:
   ```bash
   pip install requests python-dotenv
   ```

## Usage

### Smart Batch Downloader (Recommended)
To download all contracts from the benchmark while automatically resolving proxies and organizing them by case name into the replication workdir:

```bash
python3 smart_batch_fetcher.py
```

### Basic Fetchers
To download the source code for all contracts (Target address only) into a flat `downloads/` folder:

```bash
python3 batch_fetcher.py
```

To download a single specific contract:

```bash
python3 fetcher.py <CONTRACT_ADDRESS>
```

## Credits

- **Original Research**: [AI agents find $4.6M in blockchain smart contract exploits](https://red.anthropic.com/2025/smart-contracts/) by Anthropic.
- **Exploit Dataset**: Anthropic's Safety Research team ([SCONE-bench](https://github.com/safety-research/SCONE-bench/)).
- **Exploit Context**: Derived from historical data compiled by [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs).
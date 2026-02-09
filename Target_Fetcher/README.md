# Target Fetcher

Automated tool for batch downloading smart contract source code across multiple EVM chains (Ethereum, BSC, Base) to facilitate security research and AI-agent benchmarking.

## Overview

This tool was developed to automate the preparation of target environments for smart contract vulnerability research. It is specifically designed to work with the **SCONE-bench** dataset, allowing for the rapid reconstruction of historical exploit scenarios.

### Key Features
- **Multi-Chain Support**: Seamlessly switches between Ethereum (Mainnet), Binance Smart Chain (BSC), and Base.
- **Etherscan V2 API Integration**: Utilizes the latest Etherscan V2 API architecture for improved reliability and unified access.
- **Full Structure Reconstruction**: Automatically detects and reconstructs the original directory hierarchy for "Multi-part files" (e.g., `@openzeppelin/`, `interfaces/`, etc.), ensuring imports remain valid for local compilation.
- **Rate-Limit Aware**: Built-in delays to respect Free Tier API limits (5 requests per second).
- **Batch Processing**: Processes hundreds of contracts in a single run using a CSV-based task list.

## Data Source

The targets are sourced from the [SCONE-bench (Smart CONtract Exploitation benchmark)](https://github.com/safety-research/SCONE-bench/) repository by Anthropic.

The included `benchmark.csv` contains metadata for 405 historically exploited contracts, including:
- Case name
- Target contract address
- Network/Chain
- Fork block number (essential for reproducible state)

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

To download the source code for all contracts listed in `benchmark.csv`:

```bash
python3 batch_fetcher.py
```

To download a single specific contract (using the standalone fetcher logic):

```bash
python3 fetcher.py <CONTRACT_ADDRESS>
```

## Output Structure

Files are saved in the `downloads/` directory using the following hierarchy:
`downloads/<chain>/<address>/<ContractName>/<original_structure>`

This structure mirrors the environment provided to AI agents in the original SCONE-bench experiment, making it ideal for training and testing autonomous security auditors.

## Credits

- **Original Research**: [AI agents find $4.6M in blockchain smart contract exploits](https://red.anthropic.com/2025/smart-contracts/) by Anthropic.
- **Exploit Dataset**: Anthropic's Safety Research team ([SCONE-bench](https://github.com/safety-research/SCONE-bench/)).
- **Exploit Context**: Derived from historical data compiled by [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs).

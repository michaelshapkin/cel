# Environment Scanner & Prompt Generator

Automated tools for extracting smart contract state and generating high-fidelity research contexts for AI agents.

## Overview

This module is responsible for "Reality Reconstruction." It bridges the gap between a frozen blockchain state (Anvil fork) and the AI agent's mental model by generating a comprehensive system prompt that mirrors the environment used in **Anthropic's 2025 research**.

### Key Components

#### 1. `scanner.py` (Technical State Extractor)
A low-level utility that probes the target contract's internal state.
- **Proxy-Aware**: Automatically detects EIP-1967 proxies and resolves implementation addresses.
- **Auto-Discovery**: Fetches the contract ABI via Etherscan/BscScan API and identifies all `view`/`pure` getter functions.
- **Direct Probing**: Executes `eth_call` for every identified variable to capture the exact state at the pinned block.

#### 2. `generate_context.py` (Reality Synthesizer)
An orchestrator that assembles the complete "Vulnerability Challenge" prompt.
- **Metadata Integration**: Reads `benchmark.csv` to pull case names and historical block numbers.
- **Dynamic Liquidity Discovery**: Scans multiple DEX factories (PancakeSwap, Uniswap, BiSwap, ApeSwap) to find active trading pairs and verified liquidity for the target.
- **Balance Auditing**: Checks the contract's holdings across major stablecoins and native wrapped tokens.
- **Formatting**: Outputs a standardized Markdown prompt (identical to Anthropic's "Step 0" logs).

## Setup

1. Navigate to the directory:
   ```bash
   cd Environment_Scanner
   ```
2. Create a `.env` file with your API keys:
   ```env
   ETHERSCAN_API_KEY=your_key_here
   BSC_API_KEY=your_key_here
   ```
3. Install dependencies:
   ```bash
   pip install web3 requests python-dotenv
   ```

## Usage

To generate a full system prompt for a specific contract (e.g., WebKeyDAO):

```bash
python3 generate_context.py 0xd511096a73292a7419a94354d4c1c73e8a3cd851
```

*Note: Ensure your Anvil fork is running on the correct block before executing the generator.*

## How Liquidity Scanning Works

Unlike static lists, this tool performs **on-chain discovery**:
1. It queries `getPair` (V2) or `getPool` (V3) on all registered DEX factories.
2. It verifies the existence of a pool between the target and a base token (WBNB/WETH/USDT).
3. It checks the `balanceOf` the pool address to confirm actual liquidity exists at that specific block.

## Credits

- **Original Research**: [AI agents find $4.6M in blockchain smart contract exploits](https://red.anthropic.com/2025/smart-contracts/) by Anthropic.
- **Dataset**: Part of the [SCONE-bench](https://github.com/safety-research/SCONE-bench/) replication suite.

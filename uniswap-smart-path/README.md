# Uniswap Smart Path

CLI routing tool for smart contract exploitation research and AI-agent benchmarking.

## Overview

This tool is a faithful replication of the internal utility used by **Anthropic researchers** in their 2025 smart contract vulnerability study. It enables security researchers and AI agents to identify optimal liquidation routes for tokens within a forked blockchain environment (e.g., Anvil).

In the context of an exploit, this tool answers the critical question: *"What is the most profitable path to convert my extracted tokens back into native BNB/ETH?"*

### Key Features
- **Optimal Route Discovery**: Compares direct swaps vs. multi-hop paths (e.g., `Token -> USDT -> WBNB`).
- **Real-Time Data**: Queries reserves directly from the blockchain state using `staticcall` (no state changes).
- **Local Fork Compatibility**: Designed to work seamlessly with `anvil` or `hardhat` forks.
- **Anthropic-Compatible Interface**: Matches the exact CLI arguments used in the SCONE-bench experiments.

## Prerequisites

- Python 3.11+
- A running Ethereum/BSC fork (Anvil recommended) at a specific historical block.

## Setup

1. Navigate to the directory:
   ```bash
   cd uniswap-smart-path
   ```
2. Create a `.env` file:
   ```env
   ANVIL_RPC_URL=http://127.0.0.1:8545
   ```
3. Install dependencies:
   ```bash
   pip install web3 python-dotenv
   ```

## Usage

To find the best path for swapping **WKEY** to **WBNB** through **USDT** on PancakeSwap V2:

```bash
python3 uniswap-smart-path.py 
  --token-in 0x194B302a4b0a79795Fb68E2ADf1B8c9eC5ff8d1F 
  --token-out 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c 
  --exact-amount-in 1000000000 
  --pivot-tokens 0x55d398326f99059fF775485246999027B3197955 
  --v2-router 0x10ED43C718714eb63d5aA57B78B54704E256024E
```

## How It Works

1. **Path Generation**: Constructs candidate routes (Direct and via provided Pivot Tokens).
2. **On-Chain Validation**: Calls `getAmountsOut` on the target V2 Router for every path.
3. **Profit Comparison**: Identifies the path that yields the highest amount of the destination token.
4. **Error Handling**: Gracefully skips routes with no liquidity or those that result in execution reverts.

## Credits

- **Original Research**: [AI agents find $4.6M in blockchain smart contract exploits](https://red.anthropic.com/2025/smart-contracts/) by Anthropic.
- **Experimental Context**: Part of the [SCONE-bench](https://github.com/safety-research/SCONE-bench/) replication suite.

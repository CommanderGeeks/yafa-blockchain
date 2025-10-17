#!/bin/bash
# Deploy YAFA Token to L2 via L1 OptimismPortal using cast

set -e

# Load environment variables
source .env

# Configuration
PORTAL="0xa5ed72d0ebfeec112a0b3e9edc589a7916fc2a72"
L1_RPC="$L1_RPC_URL"
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "🚀 Deploying YAFA Token to L2 via L1 Portal"
echo "============================================"
echo ""
echo "Portal Address: $PORTAL"
echo "Deployer: $DEPLOYER"
echo ""

# Check L1 balance
echo "📊 Checking L1 balance..."
L1_BALANCE=$(cast balance $DEPLOYER --rpc-url $L1_RPC)
echo "L1 Balance: $(cast --to-unit $L1_BALANCE ether) ETH"
echo ""

# Compile contract to get bytecode
echo "🔨 Compiling contract..."
cd yafa-contracts
forge build --silent
cd ..

# Get the bytecode
BYTECODE=$(jq -r '.bytecode.object' yafa-contracts/out/YafaToken.sol/YafaToken.json)
echo "Bytecode length: ${#BYTECODE} characters"

# Encode constructor arguments (1 billion YAFA initial supply)
INITIAL_SUPPLY="1000000000000000000000000000"  # 1 billion with 18 decimals
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(uint256)" $INITIAL_SUPPLY)

# Combine bytecode + constructor args
DEPLOYMENT_DATA="${BYTECODE}${CONSTRUCTOR_ARGS:2}"  # Remove 0x from args
echo "Full deployment data length: ${#DEPLOYMENT_DATA} characters"
echo ""

# Calculate gas limit (bytecode length * 40 + 21000)
CALLDATA_LEN=$((${#DEPLOYMENT_DATA} / 2))
MIN_GAS=$((CALLDATA_LEN * 40 + 21000))
L2_GAS_LIMIT=2000000  # Use 2M to be safe

echo "📝 Deployment Parameters:"
echo "  _to: 0x0000000000000000000000000000000000000000 (contract creation)"
echo "  _value: 0"
echo "  _gasLimit: $L2_GAS_LIMIT"
echo "  _isCreation: true"
echo "  Minimum gas required: $MIN_GAS"
echo ""

# Confirm before proceeding
read -p "🔍 Ready to deploy. Press ENTER to continue or Ctrl+C to cancel..."
echo ""

# Call depositTransaction on the portal
echo "🔄 Calling depositTransaction on L1 Portal..."
echo ""

TX_HASH=$(cast send $PORTAL \
  "depositTransaction(address,uint256,uint64,bool,bytes)" \
  "0x0000000000000000000000000000000000000000" \
  "0" \
  "$L2_GAS_LIMIT" \
  "true" \
  "$DEPLOYMENT_DATA" \
  --rpc-url $L1_RPC \
  --private-key $PRIVATE_KEY \
  --gas-limit 1000000 \
  --json | jq -r '.transactionHash')

echo "✅ Transaction sent!"
echo "L1 TX Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "⏳ Waiting for L1 confirmation..."
cast receipt $TX_HASH --rpc-url $L1_RPC > /dev/null
echo "✅ Confirmed on L1!"
echo ""

# Get receipt details
echo "📋 Transaction Receipt:"
cast receipt $TX_HASH --rpc-url $L1_RPC | grep -E "(blockNumber|gasUsed|status)"
echo ""

echo "⏳ Contract will be deployed on L2 within 1-2 minutes"
echo "   (waiting for sequencer to process the deposit)"
echo ""
echo "📍 To find your contract address:"
echo "   Wait 2 minutes, then check L2 transactions from your address:"
echo "   cast nonce $DEPLOYER --rpc-url http://localhost:8545"
echo ""
echo "   Or check recent blocks on L2 for contract deployments:"
echo "   cast block latest --rpc-url http://localhost:8545"
echo ""
echo "✅ Deployment initiated successfully!"
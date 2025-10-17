#!/bin/bash
# Complete YAFA Token deployment via L1 OptimismPortal
# This script handles: compile -> deploy -> wait -> verify

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }
echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Load environment
if [ ! -f .env ]; then
    echo_error ".env file not found!"
    echo_info "Create .env with: PRIVATE_KEY, L1_RPC_URL"
    exit 1
fi

source .env

# Configuration
PORTAL="0xa5ed72d0ebfeec112a0b3e9edc589a7916fc2a72"
L1_RPC="$L1_RPC_URL"
L2_RPC="http://localhost:8545"
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║     YAFA Token L2 Deployment via L1 Portal        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo_info "Portal Address: $PORTAL"
echo_info "Deployer: $DEPLOYER"
echo ""

# Step 1: Check prerequisites
echo "📋 Step 1/6: Checking prerequisites..."

# Check L2 is running
if ! curl -s -X POST $L2_RPC -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0xa455"; then
    echo_error "L2 is not running or not responding"
    echo_info "Start it with: docker-compose up -d"
    exit 1
fi
echo_success "L2 is running (Chain ID: 42069)"

# Check L1 balance
L1_BALANCE=$(cast balance $DEPLOYER --rpc-url $L1_RPC)
L1_BALANCE_ETH=$(cast --to-unit $L1_BALANCE ether)
echo_info "L1 Balance: $L1_BALANCE_ETH ETH"

if (( $(echo "$L1_BALANCE_ETH < 0.05" | bc -l) )); then
    echo_error "Insufficient L1 balance. Need at least 0.05 ETH"
    echo_info "Get Sepolia ETH from: https://sepoliafaucet.com/"
    exit 1
fi
echo_success "L1 balance sufficient"

# Check L2 balance
L2_BALANCE=$(cast balance $DEPLOYER --rpc-url $L2_RPC)
L2_BALANCE_ETH=$(cast --to-unit $L2_BALANCE ether)
echo_info "L2 Balance: $L2_BALANCE_ETH ETH"

# Step 2: Compile contract
echo ""
echo "🔨 Step 2/6: Compiling contract..."
cd yafa-contracts

if [ ! -f "contracts/YafaToken.sol" ]; then
    echo_error "YafaToken.sol not found!"
    exit 1
fi

forge build --force
if [ $? -ne 0 ]; then
    echo_error "Compilation failed!"
    exit 1
fi
echo_success "Contract compiled"

# Step 3: Prepare deployment data
echo ""
echo "📦 Step 3/6: Preparing deployment transaction..."

# Find the compiled contract (could be in out/ or artifacts/)
if [ -f "yafa-contracts/artifacts/YafaToken.sol/YafaToken.json" ]; then
    CONTRACT_JSON="yafa-contracts/artifacts/YafaToken.sol/YafaToken.json"
elif [ -f "yafa-contracts/out/YafaToken.sol/YafaToken.json" ]; then
    CONTRACT_JSON="yafa-contracts/out/YafaToken.sol/YafaToken.json"
elif [ -f "yafa-contracts/artifacts/contracts/YafaToken.sol/YafaToken.json" ]; then
    CONTRACT_JSON="yafa-contracts/artifacts/contracts/YafaToken.sol/YafaToken.json"
else
    echo_error "Cannot find compiled YafaToken.json"
    echo_info "Tried:"
    echo_info "  - yafa-contracts/artifacts/YafaToken.sol/YafaToken.json"
    echo_info "  - yafa-contracts/out/YafaToken.sol/YafaToken.json"
    echo_info "  - yafa-contracts/artifacts/contracts/YafaToken.sol/YafaToken.json"
    exit 1
fi

echo_info "Using contract: $CONTRACT_JSON"
BYTECODE=$(jq -r '.bytecode.object' "$CONTRACT_JSON")
if [ "$BYTECODE" == "null" ] || [ -z "$BYTECODE" ]; then
    echo_error "Failed to read bytecode"
    exit 1
fi

# Constructor args: initialSupply = 1 billion YAFA
INITIAL_SUPPLY="1000000000000000000000000000"  # 1B with 18 decimals
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(uint256)" $INITIAL_SUPPLY)
DEPLOYMENT_DATA="${BYTECODE}${CONSTRUCTOR_ARGS:2}"

echo_info "Bytecode length: ${#BYTECODE} chars"
echo_info "Full deployment data: ${#DEPLOYMENT_DATA} chars"
echo_info "Initial supply: 1,000,000,000 YAFA"

# Calculate required gas
CALLDATA_LEN=$((${#DEPLOYMENT_DATA} / 2))
MIN_GAS=$((CALLDATA_LEN * 40 + 21000))
L2_GAS_LIMIT=2500000

echo_info "Minimum L2 gas: $MIN_GAS"
echo_info "Using L2 gas limit: $L2_GAS_LIMIT"
echo_success "Deployment data prepared"

# Step 4: Deploy via L1 Portal
echo ""
echo "🚀 Step 4/6: Deploying to L2 via L1 Portal..."
echo_warning "This will send a transaction on L1 (Sepolia)"
echo ""
read -p "Press ENTER to continue or Ctrl+C to cancel..."

cd ..
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

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo_error "Failed to send transaction"
    exit 1
fi

echo_success "Transaction sent!"
echo_info "L1 TX Hash: $TX_HASH"
echo_info "View on Etherscan: https://sepolia.etherscan.io/tx/$TX_HASH"

# Step 5: Wait for L1 confirmation
echo ""
echo "⏳ Step 5/6: Waiting for L1 confirmation..."
cast receipt $TX_HASH --rpc-url $L1_RPC --confirmations 1 > /dev/null
echo_success "Confirmed on L1!"

# Get nonce before deployment
NONCE_BEFORE=$(cast nonce $DEPLOYER --rpc-url $L2_RPC)
echo_info "L2 nonce before: $NONCE_BEFORE"

# Step 6: Wait for L2 deployment
echo ""
echo "⏳ Step 6/6: Waiting for L2 deployment (this takes 1-2 minutes)..."
echo_info "The sequencer needs to process the deposit and deploy the contract"

MAX_WAIT=180  # 3 minutes
ELAPSED=0
FOUND=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    
    CURRENT_NONCE=$(cast nonce $DEPLOYER --rpc-url $L2_RPC)
    
    if [ "$CURRENT_NONCE" -gt "$NONCE_BEFORE" ]; then
        echo_success "Nonce increased! Contract deployed."
        FOUND=true
        break
    fi
    
    echo_info "Waiting... ($ELAPSED/${MAX_WAIT}s) - Nonce still $CURRENT_NONCE"
done

if [ "$FOUND" = false ]; then
    echo_error "Deployment timed out after ${MAX_WAIT}s"
    echo_info "Check op-node logs: docker-compose logs op-node | grep deposit"
    exit 1
fi

# Find the contract address
echo ""
echo "🔍 Finding deployed contract address..."

# Try each nonce from NONCE_BEFORE to CURRENT_NONCE
for nonce in $(seq $NONCE_BEFORE $((CURRENT_NONCE - 1))); do
    POTENTIAL_ADDR=$(cast compute-address --nonce $nonce $DEPLOYER 2>/dev/null || echo "")
    
    if [ -n "$POTENTIAL_ADDR" ]; then
        CODE=$(cast code $POTENTIAL_ADDR --rpc-url $L2_RPC)
        if [ "$CODE" != "0x" ] && [ ${#CODE} -gt 4 ]; then
            # Verify it's YafaToken
            NAME=$(cast call $POTENTIAL_ADDR "name()(string)" --rpc-url $L2_RPC 2>/dev/null || echo "")
            if [ -n "$NAME" ]; then
                CONTRACT_ADDR=$POTENTIAL_ADDR
                break
            fi
        fi
    fi
done

if [ -z "$CONTRACT_ADDR" ]; then
    echo_error "Could not find contract address"
    echo_info "Try running: ./find-deployed-contract.sh"
    exit 1
fi

# Verify the deployment
echo ""
echo "✅ Verifying deployment..."
NAME=$(cast call $CONTRACT_ADDR "name()(string)" --rpc-url $L2_RPC)
SYMBOL=$(cast call $CONTRACT_ADDR "symbol()(string)" --rpc-url $L2_RPC)
DECIMALS=$(cast call $CONTRACT_ADDR "decimals()(uint8)" --rpc-url $L2_RPC)
TOTAL_SUPPLY=$(cast call $CONTRACT_ADDR "totalSupply()(uint256)" --rpc-url $L2_RPC)
SUPPLY_ETH=$(cast --to-unit $TOTAL_SUPPLY ether)
OWNER_BALANCE=$(cast call $CONTRACT_ADDR "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $L2_RPC)
OWNER_BALANCE_ETH=$(cast --to-unit $OWNER_BALANCE ether)

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║           🎉 DEPLOYMENT SUCCESSFUL! 🎉            ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "📝 Contract Details:"
echo "  Name: $NAME"
echo "  Symbol: $SYMBOL"
echo "  Decimals: $DECIMALS"
echo "  Total Supply: $SUPPLY_ETH YAFA"
echo "  Your Balance: $OWNER_BALANCE_ETH YAFA"
echo ""
echo "📍 Contract Address: $CONTRACT_ADDR"
echo "🔗 L1 Transaction: https://sepolia.etherscan.io/tx/$TX_HASH"
echo ""

# Save deployment info
cat > deployment-l2.json << EOF
{
  "network": "yafa-l2",
  "chainId": 42069,
  "l2Rpc": "$L2_RPC",
  "contracts": {
    "YafaToken": "$CONTRACT_ADDR"
  },
  "deployer": "$DEPLOYER",
  "l1Transaction": "$TX_HASH",
  "deploymentNonce": $nonce,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tokenInfo": {
    "name": "$NAME",
    "symbol": "$SYMBOL",
    "decimals": $DECIMALS,
    "totalSupply": "$TOTAL_SUPPLY"
  }
}
EOF

echo_success "Deployment info saved to deployment-l2.json"
echo ""
echo "📋 Next Steps:"
echo "  1. Add token to MetaMask:"
echo "     Network: Yafa L2 (http://localhost:8545, Chain ID: 42069)"
echo "     Token: $CONTRACT_ADDR"
echo ""
echo "  2. Deploy DEX contract using the same method"
echo ""
echo "  3. Update your frontend with the contract address"
echo ""
echo "  4. Test a transfer:"
echo "     cast send $CONTRACT_ADDR \"transfer(address,uint256)\" \\"
echo "       <recipient> 1000000000000000000 \\"
echo "       --rpc-url $L2_RPC --private-key \$PRIVATE_KEY"
echo ""
echo_success "All done! Your YAFA L2 token is live! 🚀"
#!/bin/bash
# Find the deployed YAFA Token contract on L2

set -e

source .env

DEPLOYER="0xa0ADc7552E130Da3C82d45AB110C7096ac774f5f"
L2_RPC="http://localhost:8545"

echo "🔍 Searching for deployed YAFA Token contract..."
echo "================================================"
echo ""
echo "Deployer Address: $DEPLOYER"
echo "L2 RPC: $L2_RPC"
echo ""

# Check current nonce
echo "📊 Checking deployer nonce on L2..."
CURRENT_NONCE=$(cast nonce $DEPLOYER --rpc-url $L2_RPC)
echo "Current nonce: $CURRENT_NONCE"
echo ""

if [ "$CURRENT_NONCE" -eq "0" ]; then
    echo "❌ No transactions from deployer yet. Contract hasn't deployed."
    echo "   Wait 1-2 minutes after L1 transaction confirms."
    exit 1
fi

# Check recent blocks for contract creations
echo "🔎 Checking recent blocks for contract deployments..."
LATEST_BLOCK=$(cast block-number --rpc-url $L2_RPC)
START_BLOCK=$((LATEST_BLOCK - 50))

echo "Scanning blocks $START_BLOCK to $LATEST_BLOCK..."
echo ""

# Function to check if an address is a contract
is_contract() {
    local addr=$1
    local code=$(cast code $addr --rpc-url $L2_RPC)
    if [ "$code" != "0x" ] && [ ${#code} -gt 4 ]; then
        return 0  # Is a contract
    else
        return 1  # Not a contract
    fi
}

# Try to calculate contract addresses based on nonces
echo "🧮 Calculating potential contract addresses..."
for nonce in $(seq 0 $((CURRENT_NONCE - 1))); do
    # Calculate CREATE address
    POTENTIAL_ADDR=$(cast compute-address --nonce $nonce $DEPLOYER 2>/dev/null || echo "")
    
    if [ -n "$POTENTIAL_ADDR" ]; then
        echo -n "  Checking nonce $nonce -> $POTENTIAL_ADDR ... "
        
        if is_contract "$POTENTIAL_ADDR"; then
            echo "✅ FOUND CONTRACT!"
            
            # Try to call token functions to verify it's YafaToken
            echo ""
            echo "📝 Verifying contract..."
            
            NAME=$(cast call $POTENTIAL_ADDR "name()(string)" --rpc-url $L2_RPC 2>/dev/null || echo "")
            SYMBOL=$(cast call $POTENTIAL_ADDR "symbol()(string)" --rpc-url $L2_RPC 2>/dev/null || echo "")
            DECIMALS=$(cast call $POTENTIAL_ADDR "decimals()(uint8)" --rpc-url $L2_RPC 2>/dev/null || echo "")
            TOTAL_SUPPLY=$(cast call $POTENTIAL_ADDR "totalSupply()(uint256)" --rpc-url $L2_RPC 2>/dev/null || echo "")
            
            if [ -n "$NAME" ]; then
                echo "  Name: $NAME"
                echo "  Symbol: $SYMBOL"
                echo "  Decimals: $DECIMALS"
                if [ -n "$TOTAL_SUPPLY" ]; then
                    SUPPLY_ETH=$(cast --to-unit $TOTAL_SUPPLY ether)
                    echo "  Total Supply: $SUPPLY_ETH YAFA"
                fi
                echo ""
                echo "🎉 YAFA Token found at: $POTENTIAL_ADDR"
                echo ""
                echo "📋 Next steps:"
                echo "  1. Add to MetaMask using this address"
                echo "  2. Deploy DEX contract using same method"
                echo "  3. Update frontend with contract address"
                echo ""
                echo "💾 Saving address to deployment-l2.json..."
                
                cat > deployment-l2.json << EOF
{
  "network": "yafa-l2",
  "chainId": 42069,
  "contracts": {
    "YafaToken": "$POTENTIAL_ADDR"
  },
  "deployer": "$DEPLOYER",
  "nonce": $nonce,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
                
                echo "✅ Saved to deployment-l2.json"
                exit 0
            else
                echo "(Not YafaToken - different contract)"
            fi
        else
            echo "no contract"
        fi
    fi
done

echo ""
echo "❌ No YAFA Token contract found yet."
echo ""
echo "💡 Troubleshooting:"
echo "  1. Make sure L1 transaction confirmed (check Sepolia Etherscan)"
echo "  2. Wait 1-2 minutes for sequencer to process deposit"
echo "  3. Check op-node logs: docker-compose logs op-node | grep -i deposit"
echo "  4. Verify bridge contract address is correct:"
echo "     cat deployer/.deployer/rollup.json | grep deposit_contract"
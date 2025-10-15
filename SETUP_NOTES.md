# YAFA L2 - Quick Reference

## ✅ Current Status
- L2 blockchain RUNNING and producing blocks
- Chain ID: 42069
- L2 RPC: http://localhost:8545
- Block height: ~134+ blocks

## 🔑 Key Information
- Deployer Address: 0xa0ADc7552E130ba3C82dd5AB110C7096ac77Hf5F
- L1: Sepolia Testnet
- Location: ~/yafa-blockchain/docs/create-l2-rollup-example

## 🐛 Fixes Applied
1. Changed chain ID from 1948 to 42069
2. Disabled check-custom-chains validation in optimism/op-program/Makefile
3. Fixed genesis-l2.json copy in scripts/setup-rollup.sh (line changed to use genesis.json)

## 📝 Useful Commands
```bash
# Check status
docker-compose ps
make test-l2

# View logs
docker-compose logs -f

# Stop/Start
docker-compose down
docker-compose up -d

# Location
cd ~/yafa-blockchain/docs/create-l2-rollup-example
```

## 🔗 Next Steps
- Deploy custom contracts to L2 including Native bridge, YAFA Token, & DEX
- Add L2 to MetaMask
- Connect bridge-ui frontend

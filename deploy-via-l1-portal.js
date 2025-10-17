// Deploy YAFA Token to L2 via L1 OptimismPortal depositTransaction
// This is the PROPER way to deploy contracts to Optimism L2s

import { ethers } from 'ethers';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env from project root
dotenv.config({ path: path.join(__dirname, '.env') });

// Configuration
const L1_RPC_URL = process.env.L1_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const OPTIMISM_PORTAL = '0xa5ed72d0ebfeec112a0b3e9edc589a7916fc2a72'; // From your rollup.json

// Read compiled contract
const contractPath = './artifacts/contracts/YafaToken.sol/YafaToken.json';
const contractJson = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
const contractBytecode = contractJson.bytecode;

console.log('🚀 Deploying YAFA Token to L2 via L1 Portal\n');
console.log('L1 RPC:', L1_RPC_URL);
console.log('Portal Address:', OPTIMISM_PORTAL);
console.log('Bytecode length:', contractBytecode.length, 'characters\n');

// OptimismPortal ABI (just the depositTransaction function we need)
const portalABI = [
  "function depositTransaction(address _to, uint256 _value, uint64 _gasLimit, bool _isCreation, bytes memory _data) payable"
];

async function deployToL2() {
  try {
    // Check if L1_RPC_URL is set
    if (!L1_RPC_URL) {
      throw new Error('L1_RPC_URL not found in .env file');
    }
    
    if (!PRIVATE_KEY || PRIVATE_KEY === '0x') {
      throw new Error('PRIVATE_KEY not found in .env file');
    }
    
    // Connect to L1 (try ethers v6 first, then fall back to v5)
    let l1Provider, wallet;
    
    try {
      // Ethers v6 syntax
      l1Provider = new ethers.JsonRpcProvider(L1_RPC_URL);
      wallet = new ethers.Wallet(PRIVATE_KEY, l1Provider);
    } catch (e) {
      // Ethers v5 syntax
      l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC_URL);
      wallet = new ethers.Wallet(PRIVATE_KEY, l1Provider);
    }
    
    console.log('📡 Connected to L1');
    console.log('Deployer:', wallet.address);
    
    // Check L1 balance
    const l1Balance = await l1Provider.getBalance(wallet.address);
    console.log('L1 Balance:', ethers.formatEther(l1Balance), 'ETH\n');
    
    if (l1Balance < ethers.parseEther('0.05')) {
      throw new Error('Insufficient L1 balance. Need at least 0.05 ETH for deployment');
    }
    
    // Create contract interface for the portal
    const portal = new ethers.Contract(OPTIMISM_PORTAL, portalABI, wallet);
    
    // Prepare deployment data
    // For contract deployment via depositTransaction:
    // - _to = address(0) (required for contract creation)
    // - _value = 0 (no ETH sent to constructor)
    // - _gasLimit = enough gas for deployment (we'll use 2M)
    // - _isCreation = true (this is a contract deployment)
    // - _data = contract bytecode + constructor args (if any)
    
    // Encode constructor arguments (initialSupply = 1 billion YAFA)
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const constructorArgs = abiCoder.encode(['uint256'], [ethers.parseEther('1000000000')]);
    
    // Combine bytecode + constructor args
    const deploymentData = contractBytecode + constructorArgs.slice(2); // Remove '0x' from args
    
    console.log('📝 Deployment Parameters:');
    console.log('  _to: 0x0000000000000000000000000000000000000000 (contract creation)');
    console.log('  _value: 0');
    console.log('  _gasLimit: 2000000');
    console.log('  _isCreation: true');
    console.log('  _data length:', deploymentData.length, 'characters\n');
    
    // Calculate the L2 contract address
    // For deposits, the address is derived from: keccak256(rlp([sender, nonce]))
    // But we need to account for address aliasing if deploying from a contract
    // Since we're deploying from an EOA, no aliasing needed
    
    console.log('🔄 Sending deployment transaction to L1 Portal...\n');
    
    // Call depositTransaction
    const tx = await portal.depositTransaction(
      ethers.ZeroAddress,        // _to: address(0) for contract creation
      0,                          // _value: no ETH to constructor
      2000000,                    // _gasLimit: 2M gas for deployment
      true,                       // _isCreation: this is a contract deployment
      deploymentData,             // _data: bytecode + constructor args
      { 
        value: 0,                 // No ETH deposit with this call
        gasLimit: 500000          // L1 gas limit for the portal call itself
      }
    );
    
    console.log('✅ Transaction sent!');
    console.log('L1 TX Hash:', tx.hash);
    console.log('\n⏳ Waiting for confirmation...');
    
    const receipt = await tx.wait();
    console.log('\n✅ Transaction confirmed on L1!');
    console.log('Block:', receipt.blockNumber);
    console.log('Gas Used:', receipt.gasUsed.toString());
    
    // Parse the TransactionDeposited event to get L2 transaction info
    const depositEvent = receipt.logs.find(log => {
      try {
        const parsed = portal.interface.parseLog(log);
        return parsed.name === 'TransactionDeposited';
      } catch {
        return false;
      }
    });
    
    if (depositEvent) {
      console.log('\n📨 Deposit Event Found!');
      // The L2 contract address needs to be calculated based on the deposit nonce
      // For now, you'll need to check the L2 chain for the deployed contract
    }
    
    console.log('\n⏳ The contract will be deployed on L2 within ~1-2 minutes');
    console.log('   (when the sequencer processes the deposit)');
    console.log('\n📍 To find your deployed contract address:');
    console.log('   1. Wait 1-2 minutes for L2 processing');
    console.log('   2. Check your address on L2 for contract creation:');
    console.log(`      cast nonce ${wallet.address} --rpc-url http://localhost:8545`);
    console.log('   3. Or check L2 logs for contract deployment events');
    
    return receipt;
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.data) {
      console.error('Error data:', error.data);
    }
    throw error;
  }
}

// Run deployment
deployToL2()
  .then(() => {
    console.log('\n✅ Deployment initiated successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Deployment failed:', error);
    process.exit(1);
  });
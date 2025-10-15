import pkg from 'ethers';
const { ethers } = pkg;
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const SEPOLIA_RPC = process.env.L1_RPC_URL;
const L2_RPC = 'http://localhost:8545';
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// YOUR Custom Yafa L2 Bridge addresses on Sepolia
const OPTIMISM_PORTAL_PROXY = '0xa5ed72d0ebfeec112a0b3e9edc589a7916fc2a72'; // Your deposit contract

// Simple OptimismPortal ABI
const PORTAL_ABI = [
  'function depositTransaction(address _to, uint256 _value, uint64 _gasLimit, bool _isCreation, bytes memory _data) payable'
];

async function bridgeETH(amountInEth) {
  console.log('🌉 Bridging ETH from Sepolia to Yafa L2\n');

  try {
    // Setup providers (works with both ethers v5 and v6)
    const l1Provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC);
    const l2Provider = new ethers.providers.JsonRpcProvider(L2_RPC);
    
    const wallet = new ethers.Wallet(PRIVATE_KEY, l1Provider);
    
    console.log('📍 Your address:', wallet.address);
    
    // Check balances
    const l1Balance = await l1Provider.getBalance(wallet.address);
    console.log('💰 L1 (Sepolia) Balance:', ethers.utils.formatEther(l1Balance), 'ETH');
    
    const l2Balance = await l2Provider.getBalance(wallet.address);
    console.log('💰 L2 (Yafa) Balance:', ethers.utils.formatEther(l2Balance), 'ETH\n');
    
    if (l1Balance.isZero()) {
      console.log('❌ No ETH on Sepolia! Get some from a faucet first.');
      return;
    }
    
    const amount = ethers.utils.parseEther(amountInEth.toString());
    
    if (amount.gt(l1Balance)) {
      console.log('❌ Insufficient balance! You only have', ethers.utils.formatEther(l1Balance), 'ETH');
      return;
    }
    
    console.log(`🔄 Bridging ${amountInEth} ETH to Yafa L2...`);
    console.log('⏳ This will take a few minutes...\n');
    
    // Connect to OptimismPortal
    const portal = new ethers.Contract(OPTIMISM_PORTAL_PROXY, PORTAL_ABI, wallet);
    
    // Deposit to L2
    const tx = await portal.depositTransaction(
      wallet.address,  // Send to yourself on L2
      amount,
      100000,          // Gas limit on L2
      false,           // Not a contract creation
      '0x',            // No data
      { value: amount }
    );
    
    console.log('📝 Transaction sent:', tx.hash);
    console.log('🔗 View on Sepolia:', `https://sepolia.etherscan.io/tx/${tx.hash}`);
    console.log('\n⏳ Waiting for confirmation...');
    
    const receipt = await tx.wait();
    console.log('✅ L1 transaction confirmed!');
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas used: ${receipt.gasUsed.toString()}`);
    
    console.log('\n⏳ Waiting for L2 to process deposit (this takes 1-2 minutes)...');
    
    // Wait and check L2 balance
    let attempts = 0;
    const maxAttempts = 30;
    
    while (attempts < maxAttempts) {
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
      
      const newL2Balance = await l2Provider.getBalance(wallet.address);
      
      if (newL2Balance.gt(l2Balance)) {
        console.log('\n🎉 Success! ETH received on L2!');
        console.log('💰 New L2 Balance:', ethers.utils.formatEther(newL2Balance), 'ETH');
        return;
      }
      
      attempts++;
      process.stdout.write('.');
    }
    
    console.log('\n⚠️  L2 deposit still pending. Check balance in MetaMask.');
    console.log('   It can take up to 5 minutes for L2 to process.');
    
  } catch (error) {
    console.error('\n❌ Bridge failed:', error.message);
    
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.log('   Need more ETH for gas fees!');
    }
  }
}

// Get amount from command line
const amount = process.argv[2];

if (!amount) {
  console.log('Usage: node bridge-to-yafa-l2.js <amount_in_eth>');
  console.log('Example: node bridge-to-yafa-l2.js 0.1');
  process.exit(1);
}

bridgeETH(amount)
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
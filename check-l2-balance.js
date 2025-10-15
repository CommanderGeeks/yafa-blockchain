import pkg from 'ethers';
const { ethers } = pkg;

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const address = '0xa0ADc7552E130ba3C82dd5AB110C7096ac77f5F';

provider.getBalance(address).then(balance => {
  console.log('💰 L2 Balance:', ethers.utils.formatEther(balance), 'ETH');
}).catch(console.error);

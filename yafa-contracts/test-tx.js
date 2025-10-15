const { ethers } = require("ethers");
require("dotenv").config({ path: "../.env" });

async function testTx() {
  const provider = new ethers.JsonRpcProvider("http://localhost:8545");
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  console.log("Address:", wallet.address);
  const balance = await provider.getBalance(wallet.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");
  
  // Try sending a simple transaction
  try {
    const tx = await wallet.sendTransaction({
      to: wallet.address,
      value: ethers.parseEther("0.001")
    });
    console.log("TX Hash:", tx.hash);
    await tx.wait();
    console.log("✅ Transaction confirmed!");
  } catch (error) {
    console.error("❌ Error:", error.message);
    console.error("Error code:", error.code);
  }
}

testTx();

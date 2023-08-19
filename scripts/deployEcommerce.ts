import { ethers, Wallet, getDefaultProvider } from "ethers";
//import { wallet } from "../config/constants";
require("dotenv").config();
import { DecentralizedEcommerce__factory } from "../typechain-types";
const rpc = "https://alfajores-forno.celo-testnet.org";
const privateKey = process.env.NEXT_PUBLIC_EVM_PRIVATE_KEY as string;
const wallet = new Wallet(privateKey);
//const rpc = "https://polygon-mumbai.g.alchemy.com/v2/Ksd4J1QVWaOJAJJNbr_nzTcJBJU-6uP3"
//const rpc = "https://forno.celo.org"

const ECommerceAddr = "";

async function main() {
    await deployEcommerceContract();
}

async function deployEcommerceContract() {
  const provider = getDefaultProvider(rpc);
  const connectedWallet = wallet.connect(provider);

  const eCommerceFactory = new DecentralizedEcommerce__factory(connectedWallet);
  const eCommerceContract = await eCommerceFactory.deploy({gasLimit: 5000000});
  console.log("Deploying Ecommerce Contract...")
  const deployTxReceipt = await eCommerceContract.deployTransaction.wait();
  console.log(`Ecommerce Contract has been deployed at this address: ${eCommerceContract.address} on the celo testnet network`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
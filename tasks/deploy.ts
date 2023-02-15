import { ethers } from "hardhat";

async function example(): Promise<void> {
  const [account] = await ethers.getSigners();

    // Deployment
    const exchangesFactory = await ethers.getContractFactory("Exchanges");
    console.log("exchangesFactory", exchangesFactory.bytecode)

    const aaveResolverFactory = await ethers.getContractFactory("AaveResolver");
    console.log("aaveResolverFactory", aaveResolverFactory.getDeployTransaction().data)

    const flashAggregatorFactory = await ethers.getContractFactory("FlashAggregator");
    console.log("flashAggregatorFactory", flashAggregatorFactory.getDeployTransaction().data)

    const flashResolverFactory = await ethers.getContractFactory("FlashResolver");
    console.log("flashResolverFactory", flashResolverFactory.getDeployTransaction('flashAggregatorFactory').data)

    const flashReceiverFactory = await ethers.getContractFactory("FlashReceiver");
    console.log("flashReceiverFactory", flashReceiverFactory.getDeployTransaction('flashAggregatorFactory').data)

    const fee = 3;
    const treasury = account.address;

    const positionRouterFactory = await ethers.getContractFactory("PositionRouter");
    console.log("positionRouterFactory", positionRouterFactory.getDeployTransaction(
      'flashAggregatorFactory', 'exchangesFactory', fee, treasury
    ).data)

    // await (await flashReceiver.connect(account).setRouter(positionRouter.address)).wait()
}


example()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
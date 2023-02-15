import { ethers } from "hardhat";

async function example(): Promise<void> {
  const [account] = await ethers.getSigners();

    // Deployment
    const exchangesFactory = await ethers.getContractFactory("Exchanges");
    const exchanges = await exchangesFactory.deploy();
    await exchanges.deployed()
    console.log(`Exchanges deployed ${exchanges.address}`);

    const aaveResolverFactory = await ethers.getContractFactory("AaveResolver");
    const aaveResolver = await aaveResolverFactory.deploy();
    await aaveResolver.deployed()
    console.log(`AaveResolver deployed ${aaveResolver.address}`);

    const flashAggregatorFactory = await ethers.getContractFactory("FlashAggregator");
    const flashAggregator = await flashAggregatorFactory.deploy();
    await flashAggregator.deployed()
    console.log(`FlashAggregator deployed ${flashAggregator.address}`);

    const flashResolverFactory = await ethers.getContractFactory("FlashResolver");
    const flashResolver = await flashResolverFactory.deploy(flashAggregator.address);
    await flashResolver.deployed()
    console.log(`FlashResolver deployed ${flashResolver.address}`);

    const flashReceiverFactory = await ethers.getContractFactory("FlashReceiver");
    const flashReceiver = await flashReceiverFactory.deploy(flashAggregator.address);
    await flashReceiver.deployed()
    console.log(`FlashReceiver deployed ${flashReceiver.address}`);

    const fee = 3;
    const treasury = account.address;

    const positionRouterFactory = await ethers.getContractFactory("PositionRouter");
    const positionRouter = await positionRouterFactory.deploy(flashReceiver.address, exchanges.address, fee, treasury);
    await positionRouter.deployed()
    console.log(`PositionRouter deployed ${positionRouter.address}`);

    await (await flashReceiver.connect(account).setRouter(positionRouter.address)).wait()
}


example()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
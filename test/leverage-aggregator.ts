import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber } from "ethers";
import { ERC20, PositionRouter, FlashResolver, AaveResolver, Exchanges } from "../typechain-types";

import {
  closeCalldata,
  getSignerFromAddress,
  openCalldata,
  uniSwap,
} from "./utils";
import { exchanges } from "../typechain-types/src";

chai.use(solidity);
const { expect } = chai;

const DAI_CONTRACT = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ETH_CONTRACT = "0x0000000000000000000000000000000000000000";

const DEFAULT_AMOUNT = ethers.utils.parseEther("1000");

const LEVERAGE = BigNumber.from("2");

describe.skip("Leverage Aggregator", async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;

  // contracts
  let positionRouter: PositionRouter;
  let flashResolver: FlashResolver;
  let aaveResolver: AaveResolver;
  let exchanges: Exchanges;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt(
      "IERC20",
      DAI_CONTRACT
    )) as ERC20;

    daiContract = await daiContract.connect(
      await getSignerFromAddress("0x1B7BAa734C00298b9429b518D621753Bb0f6efF2")
    );

    await daiContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const aaveResolverFactory = await ethers.getContractFactory("AaveResolver");
    aaveResolver = await aaveResolverFactory.deploy();
    await aaveResolver.deployed();

    const executorImplementationFactory = await ethers.getContractFactory("ExecutorImplementation");
    const executor = await executorImplementationFactory.deploy();
    await executor.deployed();

    const flashAggregatorFactory = await ethers.getContractFactory("FlashAggregator");
    const flashAggregator = await flashAggregatorFactory.deploy();
    await flashAggregator.deployed();

    const flashResolverFactory = await ethers.getContractFactory("FlashResolver");
    flashResolver = await flashResolverFactory.deploy(flashAggregator.address);
    await flashResolver.deployed();

    const flashReceiverFactory = await ethers.getContractFactory("FlashReceiver");
    const flashReceiver = await flashReceiverFactory.deploy(flashAggregator.address);
    await flashReceiver.deployed();

    const exchangesFactory = await ethers.getContractFactory("Exchanges");
    exchanges = await exchangesFactory.deploy();
    await exchanges.deployed();

    // Leverage Aggregator deploy
    const positionRouterFactory = await ethers.getContractFactory("PositionRouter");

    positionRouter = ((await positionRouterFactory
      .connect(owner)
      .deploy(executor.address, flashReceiver.address, exchanges.address)) as unknown) as PositionRouter;
    await positionRouter.deployed();

    await flashReceiver.setRouter(positionRouter.address);
  });

  it("Open position and close position", async () => {
    const position = {
      account: owner.address,
      debt: DAI_CONTRACT,
      collateral: ETH_CONTRACT,
      amountIn: DEFAULT_AMOUNT,
      sizeDelta: LEVERAGE,
    };

    await daiContract
      .connect(owner)
      .approve(positionRouter.address, position.amountIn);
    
    const swapAmount = position.amountIn.mul(position.sizeDelta).toHexString()

    const openSwap = await uniSwap(
      swapAmount,
      position.debt,
      position.collateral,
      exchanges.address
    );

    const openPositionCallback = positionRouter.interface.getSighash(
      "openPositionCallback(address[],bytes[],bytes[],address,uint256)"
    );

    const _tokens = [position.debt];
    const _amts = [position.amountIn.mul(position.sizeDelta.sub(1))];

    const encoder = new ethers.utils.AbiCoder();

    const deposit = encoder.encode(
      ["bytes4", "address"],
      [aaveResolver.interface.getSighash("deposit(address,uint256)"), position.collateral]
    );

    const borrow = encoder.encode(
      ["bytes4", "address"],
      [aaveResolver.interface.getSighash("deposit(address,uint256)"), position.debt]
    );

    const customData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      // @ts-ignore
      [position.collateral, position.debt, swapAmount, 1, openSwap.methodParameters.calldata]
    );

    const calldataOpen = openCalldata(
      openPositionCallback,
      [aaveResolver.address, aaveResolver.address],
      [deposit, borrow],
      [customData],
      owner.address,
    );

    const { bestRoutes_ } = await flashResolver.callStatic.getData(_tokens, _amts);

    await positionRouter
      .connect(owner)
      .openPosition(position, _tokens, _amts, bestRoutes_[0], calldataOpen, []);
  });
});

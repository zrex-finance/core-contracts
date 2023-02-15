import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber } from "ethers";
import { ERC20, PositionRouter, FlashResolver, CompoundV3Resolver, Exchanges } from "../typechain-types";

import {
  inchCalldata,
  getSignerFromAddress,
  openCalldata,
  uniSwap,
} from "./utils";

chai.use(solidity);
const { expect } = chai;

const USDC_CONTRACT = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const ETH_CONTRACT = "0x0000000000000000000000000000000000000000";
const ETH_CONTRACT_2 = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const WETH_CONTRACT = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const FEE = 3 // 0.03%
const USDC_MARKET = "0xc3d688B66703497DAA19211EEdff47f25384cdc3";

const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

const DEFAULT_AMOUNT = ethers.utils.parseUnits("1000", 6);

const LEVERAGE = BigNumber.from("2");

const encoder = new ethers.utils.AbiCoder();

describe("Position compound", async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let usdcContract: ERC20;

  // contracts
  let positionRouter: PositionRouter;
  let flashResolver: FlashResolver;
  let compResolver: CompoundV3Resolver;
  let exchanges: Exchanges;

  // others
  let openPositionCallback: string;
  let closePositionCallback: string;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    usdcContract = (await ethers.getContractAt(
      "IERC20",
      USDC_CONTRACT
    )) as ERC20;

    usdcContract = await usdcContract.connect(
      await getSignerFromAddress("0x5414d89a8bF7E99d732BC52f3e6A3Ef461c0C078")
    );

    await usdcContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const compResolverFactory = await ethers.getContractFactory("CompoundV3Resolver");
    compResolver = await compResolverFactory.deploy();
    await compResolver.deployed();

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
      .deploy(flashReceiver.address, exchanges.address, FEE, owner.address)) as unknown) as PositionRouter;
    await positionRouter.deployed();

    await flashReceiver.setRouter(positionRouter.address);

    openPositionCallback = positionRouter.interface.getSighash(
      "openPositionCallback(address[],bytes[],bytes[],address,uint256)"
    );

    closePositionCallback = positionRouter.interface.getSighash(
      "closePositionCallback(address[],bytes[],bytes[],address,uint256)"
    );
  });

  it.only("open and close", async () => {
    const position = {
      account: owner.address,
      debt: USDC_CONTRACT,
      collateral: ETH_CONTRACT_2,
      amountIn: DEFAULT_AMOUNT,
      sizeDelta: LEVERAGE,
    };

    const UNISWAP_ROUTE = 1

    await usdcContract
      .connect(owner)
      .approve(positionRouter.address, position.amountIn);
    
      const swapAmount = position.amountIn.mul(position.sizeDelta)
      const swapAmountWithoutFee = swapAmount.sub(swapAmount.mul(FEE).div(10000)).toHexString()

    const openSwap = await uniSwap(
      swapAmountWithoutFee,
      position.debt,
      position.collateral,
      exchanges.address
    );

    const _tokens = [position.debt];
    const _amts = [position.amountIn.mul(position.sizeDelta.sub(1))];

    const { bestRoutes_: bestOpenRoutes, bestFee_ } = await flashResolver.callStatic.getData(_tokens, _amts);

    const deposit = compResolver.interface.encodeFunctionData("deposit", [USDC_MARKET, position.collateral, MAX_UINT]);
    const borrow = compResolver.interface.encodeFunctionData("borrow", [USDC_MARKET, position.debt, _amts[0].add(bestFee_)])

    const customOpenData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      // @ts-ignore
      [position.collateral, position.debt, swapAmountWithoutFee, UNISWAP_ROUTE, openSwap.methodParameters.calldata]
    );

    const calldataOpen = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        openPositionCallback,
        [compResolver.address, compResolver.address],
        [deposit, borrow],
        [customOpenData, position.debt],
        owner.address,
      ]
    )

    await positionRouter
      .connect(owner)
      .openPosition(position, false, _tokens, _amts, bestOpenRoutes[0], calldataOpen, []);

    const index = await positionRouter.callStatic.positionsIndex(owner.address);
    const key = await positionRouter.callStatic.getKey(owner.address, index);

    const collateralAmount = await compResolver.callStatic.collateralBalanceOf(
      USDC_MARKET, 
      positionRouter.address,
      position.collateral === ETH_CONTRACT || position.collateral === ETH_CONTRACT_2
        ? WETH_CONTRACT
        : position.collateral, 
    );

    const borrowAmount = await compResolver.callStatic.borrowBalanceOf(USDC_MARKET, positionRouter.address);

    const closeSwap = await uniSwap(
      collateralAmount.toHexString(),
      position.collateral,
      position.debt,
      exchanges.address
    );

    const __tokens = [position.debt];
    const __amts = [borrowAmount.mul(10005).div(10000).toHexString()];
    
    const payback = compResolver.interface.encodeFunctionData("payback", [USDC_MARKET, position.debt, MAX_UINT])
    const withdraw = compResolver.interface.encodeFunctionData("withdraw", [USDC_MARKET, position.collateral, MAX_UINT])

    const customCloseData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      [
        position.debt,
        position.collateral,
        collateralAmount.toHexString(),
        UNISWAP_ROUTE,
        // @ts-ignore
        closeSwap.methodParameters.calldata
      ]
    );

    const calldataClose = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        closePositionCallback,
        [compResolver.address, compResolver.address],
        [payback, withdraw],
        [customCloseData, key],
        owner.address
      ]
    )

    const { bestRoutes_: closeRoutes } = await flashResolver.callStatic.getData(__tokens, __amts);

    await positionRouter
    .connect(owner)
    .closePosition(key,__tokens,__amts,closeRoutes[0],calldataClose,[])
  });
});

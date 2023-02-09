import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber } from "ethers";
import { ERC20, PositionRouter, FlashResolver, AaveResolver, Exchanges, TokenInterface } from "../typechain-types";

import {
  inchCalldata,
  getSignerFromAddress,
  openCalldata,
  uniSwap,
} from "./utils";

chai.use(solidity);
const { expect } = chai;

const DAI_CONTRACT = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const USDC_CONTRACT = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const ETH_CONTRACT = "0x0000000000000000000000000000000000000000";
const ETH_CONTRACT_2 = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const WETH_CONTRACT = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

const DEFAULT_AMOUNT = ethers.utils.parseEther("1000");
const FEE = BigNumber.from("3"); // 0.03%
const LEVERAGE = BigNumber.from("2");

const encoder = new ethers.utils.AbiCoder();

describe("Position aave", async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;
  let wethContract: TokenInterface;

  // contracts
  let positionRouter: PositionRouter;
  let flashResolver: FlashResolver;
  let aaveResolver: AaveResolver;
  let exchanges: Exchanges;

  // others
  let openPositionCallback: string;
  let closePositionCallback: string;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt(
      "IERC20",
      DAI_CONTRACT
    )) as ERC20;

    wethContract = (await ethers.getContractAt(
      "IERC20",
      WETH_CONTRACT
    )) as unknown as TokenInterface;

    daiContract = await daiContract.connect(
      await getSignerFromAddress("0xb527a981e1d415af696936b3174f2d7ac8d11369")
    );

    await daiContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const aaveResolverFactory = await ethers.getContractFactory("AaveResolver");
    aaveResolver = await aaveResolverFactory.deploy();
    await aaveResolver.deployed();

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

  it("open and close short position", async () => {
    const UNISWAP_ROUTE = 1
    const RATE_TYPE_AAVE = 1

    const shortAmount = DEFAULT_AMOUNT.mul(2)

    await daiContract
      .connect(owner)
      .approve(positionRouter.address, shortAmount);

    const shortSwap = await uniSwap(
      shortAmount.toHexString(),
      DAI_CONTRACT,
      WETH_CONTRACT,
      exchanges.address
    );

    const shortCalldata = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      [
        WETH_CONTRACT,
        DAI_CONTRACT,
        shortAmount.toHexString(),
        UNISWAP_ROUTE,
        // @ts-ignore
        shortSwap?.methodParameters?.calldata
      ]
    )

    const position = {
      account: owner.address,
      debt: WETH_CONTRACT,
      collateral: USDC_CONTRACT,
      // @ts-ignore
      amountIn: ethers.utils.parseUnits(shortSwap.quote.toExact(), 18),
      sizeDelta: LEVERAGE,
    };

    await wethContract
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

    const deposit = aaveResolver.interface.encodeFunctionData("deposit", [position.collateral, MAX_UINT]);
    const borrow = aaveResolver.interface.encodeFunctionData("borrow", [position.debt, _amts[0].add(bestFee_), RATE_TYPE_AAVE])

    const customOpenData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      // @ts-ignore
      [position.collateral, position.debt, swapAmount, UNISWAP_ROUTE, openSwap.methodParameters.calldata]
    );

    const calldataOpen = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        openPositionCallback,
        [aaveResolver.address, aaveResolver.address],
        [deposit, borrow],
        [customOpenData, position.debt],
        owner.address,
      ]
    )

    await positionRouter
      .connect(owner)
      .openPosition(position, true, _tokens, _amts, bestOpenRoutes[0], calldataOpen, shortCalldata);

    const index = await positionRouter.callStatic.positionsIndex(owner.address);
    const key = await positionRouter.callStatic.getKey(owner.address, index);

    const collateralAmount = await aaveResolver.callStatic.getCollateralBalance(
      position.collateral === ETH_CONTRACT ? WETH_CONTRACT : position.collateral, positionRouter.address
    );

    const borrowAmount = await aaveResolver.callStatic.getPaybackBalance(
      position.debt, RATE_TYPE_AAVE, positionRouter.address
    );

    const closeSwap = await uniSwap(
      collateralAmount.toHexString(),
      position.collateral,
      position.debt,
      exchanges.address
    );

    const __tokens = [position.debt];
    const __amts = [borrowAmount.mul(105).div(100).toHexString()];
    
    const payback = aaveResolver.interface.encodeFunctionData("payback", [position.debt, MAX_UINT, RATE_TYPE_AAVE])
    const withdraw = aaveResolver.interface.encodeFunctionData("withdraw", [position.collateral, MAX_UINT])

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
        [aaveResolver.address, aaveResolver.address],
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

  it("open and close long position", async () => {
    const position = {
      account: owner.address,
      debt: DAI_CONTRACT,
      collateral: ETH_CONTRACT,
      amountIn: DEFAULT_AMOUNT,
      sizeDelta: LEVERAGE,
    };

    const UNISWAP_ROUTE = 1
    const RATE_TYPE_AAVE = 1

    await daiContract
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

    const deposit = aaveResolver.interface.encodeFunctionData("deposit", [position.collateral, MAX_UINT]);
    const borrow = aaveResolver.interface.encodeFunctionData("borrow", [position.debt, _amts[0].add(bestFee_), RATE_TYPE_AAVE])

    const customOpenData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      // @ts-ignore
      [position.collateral, position.debt, swapAmountWithoutFee, UNISWAP_ROUTE, openSwap.methodParameters.calldata]
    );

    const calldataOpen = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        openPositionCallback,
        [aaveResolver.address, aaveResolver.address],
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

    const collateralAmount = await aaveResolver.callStatic.getCollateralBalance(
      position.collateral === ETH_CONTRACT ? WETH_CONTRACT : position.collateral, positionRouter.address
    );

    const borrowAmount = await aaveResolver.callStatic.getPaybackBalance(
      position.debt, RATE_TYPE_AAVE, positionRouter.address
    );

    const closeSwap = await uniSwap(
      collateralAmount.toHexString(),
      position.collateral,
      position.debt,
      exchanges.address
    );

    const __tokens = [position.debt];
    const __amts = [borrowAmount.mul(105).div(100).toHexString()];
    
    const payback = aaveResolver.interface.encodeFunctionData("payback", [position.debt, MAX_UINT, RATE_TYPE_AAVE])
    const withdraw = aaveResolver.interface.encodeFunctionData("withdraw", [position.collateral, MAX_UINT])

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
        [aaveResolver.address, aaveResolver.address],
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

  async function openAndCloseUniPosition(UNISWAP_ROUTE: number, FLASH_ROUTE: number) {
    const position = {
      account: owner.address,
      debt: DAI_CONTRACT,
      collateral: ETH_CONTRACT,
      amountIn: DEFAULT_AMOUNT,
      sizeDelta: LEVERAGE,
    };

    const RATE_TYPE_AAVE = 1

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

    const _tokens = [position.debt];
    const _amts = [position.amountIn.mul(position.sizeDelta.sub(1))];

    const { routes_, fees_ } = await flashResolver.callStatic.getData(_tokens, _amts);

    const loanFee = _amts[0].div(10000).mul(fees_[FLASH_ROUTE]);

    const deposit = aaveResolver.interface.encodeFunctionData("deposit", [position.collateral, MAX_UINT]);
    const borrow = aaveResolver.interface.encodeFunctionData("borrow", [position.debt, _amts[0].add(loanFee), RATE_TYPE_AAVE])

    const customOpenData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      // @ts-ignore
      [position.collateral, position.debt, swapAmount, UNISWAP_ROUTE, openSwap.methodParameters.calldata]
    );

    const calldataOpen = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        openPositionCallback,
        [aaveResolver.address, aaveResolver.address],
        [deposit, borrow],
        [customOpenData, position.debt],
        owner.address,
      ]
    )

    await positionRouter
      .connect(owner)
      .openPosition(position, false, _tokens, _amts, routes_[FLASH_ROUTE], calldataOpen, []);

    const index = await positionRouter.callStatic.positionsIndex(owner.address);
    const key = await positionRouter.callStatic.getKey(owner.address, index);

    const collateralAmount = await aaveResolver.callStatic.getCollateralBalance(
      position.collateral === ETH_CONTRACT ? WETH_CONTRACT : position.collateral, positionRouter.address
    );

    const borrowAmount = await aaveResolver.callStatic.getPaybackBalance(
      position.debt, RATE_TYPE_AAVE, positionRouter.address
    );

    const closeSwap = await uniSwap(
      collateralAmount.toHexString(),
      position.collateral,
      position.debt,
      exchanges.address
    );

    const __tokens = [position.debt];
    const __amts = [borrowAmount.mul(105).div(100).toHexString()];
    
    const payback = aaveResolver.interface.encodeFunctionData("payback", [position.debt, MAX_UINT, RATE_TYPE_AAVE])
    const withdraw = aaveResolver.interface.encodeFunctionData("withdraw", [position.collateral, MAX_UINT])

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
        [aaveResolver.address, aaveResolver.address],
        [payback, withdraw],
        [customCloseData, key],
        owner.address
      ]
    )

    const { routes_: closeRoutes } = await flashResolver.callStatic.getData(__tokens, __amts);

    await positionRouter
    .connect(owner)
    .closePosition(key,__tokens,__amts,closeRoutes[FLASH_ROUTE],calldataClose,[])
  }

  it.skip("AAVE-UNI-AAVE", async () => {
    await openAndCloseUniPosition(1, 0)
  });

  it.skip("MAKER-UNI-AAVE", async () => {
    await openAndCloseUniPosition(1, 1)
  });

  it.skip("BALANCER-UNI-AAVE", async () => {
    await openAndCloseUniPosition(1, 2)
  });

  async function openAndCloseInchPosition(ONEINCH_ROUTE: number,FLASH_ROUTE: number) {
    const position = {
      account: owner.address,
      debt: DAI_CONTRACT,
      collateral: ETH_CONTRACT,
      amountIn: DEFAULT_AMOUNT,
      sizeDelta: LEVERAGE,
    };

    const RATE_TYPE_AAVE = 1

    await daiContract
      .connect(owner)
      .approve(positionRouter.address, position.amountIn);
    
    const swapAmount = position.amountIn.mul(position.sizeDelta).toString()

    const openSwap = await inchCalldata({
      fromAddress: exchanges.address,
      fromToken: position.debt,
      toToken: position.collateral,
      amount: swapAmount,
      slippage: 50,
    })

    const _tokens = [position.debt];
    const _amts = [position.amountIn.mul(position.sizeDelta.sub(1))];

    const { routes_, fees_ } = await flashResolver.callStatic.getData(_tokens, _amts);

    const loanFee = _amts[0].div(10000).mul(fees_[FLASH_ROUTE]);

    const deposit = aaveResolver.interface.encodeFunctionData("deposit", [position.collateral, MAX_UINT]);
    const borrow = aaveResolver.interface.encodeFunctionData("borrow", [position.debt, _amts[0].add(loanFee), RATE_TYPE_AAVE])

    const customOpenData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      [position.collateral, position.debt, swapAmount, ONEINCH_ROUTE, openSwap]
    );

    const calldataOpen = openCalldata(
      openPositionCallback,
      [aaveResolver.address, aaveResolver.address],
      [deposit, borrow],
      [customOpenData, position.debt],
      owner.address,
    );

    await positionRouter
      .connect(owner)
      .openPosition(position, false, _tokens, _amts, routes_[FLASH_ROUTE], calldataOpen, []);

    const index = await positionRouter.callStatic.positionsIndex(owner.address);
    const key = await positionRouter.callStatic.getKey(owner.address, index);

    const collateralAmount = await aaveResolver.callStatic.getCollateralBalance(
      position.collateral === ETH_CONTRACT ? WETH_CONTRACT : position.collateral, positionRouter.address
    );

    const borrowAmount = await aaveResolver.callStatic.getPaybackBalance(
      position.debt, RATE_TYPE_AAVE, positionRouter.address
    );

    const closeSwap = await inchCalldata({
      fromAddress: exchanges.address,
      fromToken: position.collateral,
      toToken: position.debt,
      amount: collateralAmount.toString(),
      slippage: 50,
    })

    const __tokens = [position.debt];
    const __amts = [borrowAmount.mul(105).div(100).toHexString()];
    
    const payback = aaveResolver.interface.encodeFunctionData("payback", [position.debt, MAX_UINT, RATE_TYPE_AAVE])
    const withdraw = aaveResolver.interface.encodeFunctionData("withdraw", [position.collateral, MAX_UINT])

    const customCloseData = encoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      [
        position.debt,
        position.collateral,
        collateralAmount.toHexString(),
        ONEINCH_ROUTE,
        closeSwap
      ]
    );

    const calldataClose = encoder.encode(
      ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
      [
        closePositionCallback,
        [aaveResolver.address, aaveResolver.address],
        [payback, withdraw],
        [customCloseData, key],
        owner.address
      ]
    )

    const { routes_: closeRoutes } = await flashResolver.callStatic.getData(__tokens, __amts);

    await positionRouter
    .connect(owner)
    .closePosition(key,__tokens,__amts,closeRoutes[FLASH_ROUTE],calldataClose,[])
  }

  it.skip("AAVE-1INCH-AAVE", async () => {
    openAndCloseInchPosition(2, 0);
  });

  it.skip("MAKER-1INCH-AAVE", async () => {
    openAndCloseInchPosition(2, 1);
  });

  it.skip("BALANCER-1INCH-AAVE", async () => {
    openAndCloseInchPosition(2, 2);
  });
});

/* global ethers, network */
import { ethers, network } from "hardhat";
import { BigNumber, providers } from "ethers";
import axios from "axios";
import { AlphaRouter, SwapType } from "@uniswap/smart-order-router";
import { CurrencyAmount, Percent, Token, TradeType } from "@uniswap/sdk-core";
import { Protocol } from "@uniswap/router-sdk";

export async function setTime(timestamp: number) {
  await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
}

export async function takeSnapshot() {
  return ethers.provider.send("evm_snapshot", []);
}

export async function revertSnapshot(id: string) {
  return ethers.provider.send("evm_revert", [id]);
}

export async function advanceTime(sec: number) {
  const now = (await ethers.provider.getBlock("latest")).timestamp;
  await setTime(now + sec);
}

// export async function getSignerFromAddress(address: string) {
//   const provider = new providers.JsonRpcProvider('https://hardhat.ztake.org/havilov/');
//
//   await provider.send("hardhat_impersonateAccount", [address]);
//
//   return provider.getUncheckedSigner(address);
// }

export async function getSignerFromAddress(address: string) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });

  return ethers.provider.getSigner(address);
}

export async function inchCalldata({
  fromAddress,
  fromToken,
  toToken,
  amount,
  slippage,
}: {
  fromAddress: string;
  fromToken: string;
  toToken: string;
  amount: string;
  slippage: number;
}) {
  const { data: response } = await axios.get<{ protocols: { id: string }[] }>(
    "https://api.1inch.exchange/v4.0/1/liquidity-sources"
  );

  const protocols = await response.protocols
    .filter((i: { id: string }) => i.id !== "ZRX")
    .map((p: { id: string }) => p.id)
    .join(",");
  const call = `https://api.1inch.exchange/v4.0/1/swap?fromTokenAddress=${fromToken}&toTokenAddress=${toToken}&amount=${amount}&fromAddress=${fromAddress}&slippage=${slippage}&protocols=${protocols}&disableEstimate=true&usePatching=true`;

  const { data: resp } = await axios.get<{
    tx: { data: string; value: string };
  }>(call);

  let offset;

  if (resp.tx.data.startsWith("0x7c025200")) {
    // swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)
    offset = (1 + 4 + 32 * 7) * 2;
  } else if (resp.tx.data.startsWith("0x2e95b6c8")) {
    // unoswap(address,uint256,uint256,bytes32[])
    offset = (1 + 4 + 32) * 2;
  } else if (resp.tx.data.startsWith("0xb0431182")) {
    // clipperSwap(address,address,uint256,uint256)
    offset = (1 + 4 + 32 * 2) * 2;
  } else if (resp.tx.data.startsWith("0xd0a3b665")) {
    // fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)
    offset = (1 + 4 + 32 * 9) * 2;
  } else if (resp.tx.data.startsWith("0xe449022e")) {
    // uniswapV3Swap(uint256,uint256,uint256[])
    offset = (1 + 4) * 2;
  } else {
    throw new Error("Unsupported 1inch method");
  }

  const prefix = resp.tx.data.slice(0, offset);
  const postfix = `0x${resp.tx.data.slice(offset + 64)}`;
  return { prefix, postfix };
}

const provider = new ethers.providers.JsonRpcProvider(
  "https://mainnet.infura.io/v3/eb6a84e726614079948e0b1efce5baa5",
  1
);

// @ts-ignore
const router = new AlphaRouter({ provider, chainId: 1 });

export async function uniSwap(
  amount: string,
  fromToken: string,
  toToken: string,
  recipient: string
) {
  const WETH_CONTRACT = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const ETH_CONTRACT = "0x0000000000000000000000000000000000000000";

  const FROM_TOKEN = new Token(
    1,
    fromToken === ETH_CONTRACT ? WETH_CONTRACT : fromToken,
    18
  );
  const TO_TOKEN = new Token(
    1,
    toToken === ETH_CONTRACT ? WETH_CONTRACT : toToken,
    18
  );

  return router.route(
    CurrencyAmount.fromRawAmount(FROM_TOKEN, amount),
    TO_TOKEN,
    TradeType.EXACT_INPUT,
    {
      type: SwapType.SWAP_ROUTER_02,
      recipient,
      deadline: Date.now() + 3600 * 10,
      slippageTolerance: new Percent(50),
    },
    {
      protocols: [Protocol.V2, Protocol.V3],
    }
  );
}

export function openCalldata(
   sig: string,
   _targets: string[],
   _datas: string[],
   _customDatas: string[],
   _origin: string,
) {
  const encoder = new ethers.utils.AbiCoder();

  return encoder.encode(
    ["bytes4", "address[]", "bytes[]", "bytes[]", "address"],
    [sig, _targets, _datas, _customDatas, _origin]
  );
}

export function closeCalldata(
  sig: string,
  collateral: string,
  debt: string,
  owner: string,
  amount: BigNumber,
  calldata: string
) {
  const encoder = new ethers.utils.AbiCoder();

  const closeCallback = encoder.encode(
    ["bytes4", "address", "address", "address", "uint256", "bytes"],
    [sig, collateral, debt, owner, amount.toHexString(), calldata]
  );

  return encoder.encode(
    ["address[]", "uint256[]", "uint256[]", "uint16", "bytes"],
    [[debt], [amount.toHexString()], [0], 0, closeCallback]
  );
}

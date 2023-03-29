import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import chai from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { BigNumber } from 'ethers';
import { ERC20, Router, InchV5Connector } from '../typechain-types';

import { inchCalldata, getSignerFromAddress } from './utils';

chai.use(solidity);
const { expect } = chai;

const USDC_CONTRACT = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
const DAI_CONTRACT = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const ETH_CONTRACT_2 = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';

const DEFAULT_AMOUNT = ethers.utils.parseUnits('1000', 6);

describe('OneInch v5 connector', async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;

  // contracts
  let inchV5Connector: InchV5Connector;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt('IERC20', DAI_CONTRACT)) as ERC20;

    // usdcContract = await usdcContract.connect(
    //   await getSignerFromAddress("0x5414d89a8bF7E99d732BC52f3e6A3Ef461c0C078")
    // );

    const inchV5ConnectorFactory = await ethers.getContractFactory('InchV5Connector');
    inchV5Connector = await inchV5ConnectorFactory.deploy();
    await inchV5Connector.deployed();
  });

  it('Swap ETH to USDC', async () => {
    const swapAmount = ethers.utils.parseEther('10');

    const [calldata] = await inchCalldata({
      fromAddress: inchV5Connector.address,
      fromToken: ETH_CONTRACT_2,
      toToken: DAI_CONTRACT,
      amount: swapAmount.toString(),
      slippage: 5,
    });

    await inchV5Connector
      .connect(other)
      .swap(DAI_CONTRACT, ETH_CONTRACT_2, swapAmount, calldata as string, { value: swapAmount });

    expect(
      parseInt(ethers.utils.formatEther((await daiContract.callStatic.balanceOf(inchV5Connector.address)).toString())),
    ).to.greaterThan(0);
  });
});

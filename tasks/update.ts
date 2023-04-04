import { BytesLike } from 'ethers';
import { ethers, artifacts } from 'hardhat';

const EIP_DEPLOYER = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
const SALT = '0x0000000000000000000000000000000000000000000000000000000447441964';

const ACL_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697';
const CONNECTOR_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697';
const ROUTER_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697';

const TREASURY = '0x3E324D5C62762BCbC9203Ab624d6Cd5d5066d170';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const FEE = 3;
const BUMP_GAS_PRECENT = 130;
const DEFAULT_GAS_LIMIT = 2500000;

const defaultGasParams = {
  maxFeePerGas: 35e9,
  maxPriorityFeePerGas: 3e9,
};

import routerArtifact from './artifacts/Router.json';
import configuratorArtifact from './artifacts/Configurator.json';

async function update() {
  const provider = await ethers.getContractAt("AddressesProvider", "0x020ceb63149144087b5fb93174c6086555a7dde5");

  const routerImpl = await deployRouter(provider.address);
  const configuratorImpl = await deployConfigurator();

  const configurator = await setImplToAddressesProvider(provider.address, routerImpl, configuratorImpl);

  const flashAggregator = await deployFlashAggregator();
  await deployFlashResolver(flashAggregator);

  const account = await deployAccount(provider.address);

  await setLeftAddressesToAddressesProvider(provider.address, account, flashAggregator);
}

// 1 step
async function deployRouter(addressesProviderAddress: string) {
  const bytecode = await getDeployByteCode(routerArtifact.abi, routerArtifact.bytecode, [addressesProviderAddress]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${routerArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

async function deployConfigurator() {
  const bytecode = await getDeployByteCode(configuratorArtifact.abi, configuratorArtifact.bytecode, []);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${configuratorArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

// 2 step
async function setImplToAddressesProvider(provider: string, router: string, configurator: string) {
  const addressesProvider = await ethers.getContractAt('AddressesProvider', provider);

  const gasLimit1 = await addressesProvider.estimateGas.setRouterImpl(router);
  await addressesProvider.setRouterImpl(router, {
    gasLimit: gasLimit1.add(gasLimit1.mul(BUMP_GAS_PRECENT).div(100)),
    ...defaultGasParams,
  });

  const gasLimit2 = await addressesProvider.estimateGas.setConfiguratorImpl(configurator);
  const result = await addressesProvider.setConfiguratorImpl(configurator, {
    gasLimit: gasLimit2.add(gasLimit2.mul(BUMP_GAS_PRECENT).div(100)),
    ...defaultGasParams,
  });
  await result.wait(3);

  const configuratorProxy = await addressesProvider.callStatic.getConfigurator();

  if (configuratorProxy === ZERO_ADDRESS) {
    throw new Error('configurator proxy is 0x');
  }

  return configuratorProxy;
}

// 3 step
async function deployFlashAggregator() {
  const address = await _deploy('FlashAggregator', []);
  console.log(`FlashAggregator: ${address}`);
  return address;
}

// 4 step
async function deployFlashResolver(flashAggregatorAddress: string) {
  const address = await _deploy('FlashResolver', [flashAggregatorAddress]);
  console.log(`FlashResolver: ${address}`);
  return address;
}

// 5 step
async function deployAccount(addressesProvider: string) {
  const address = await _deploy('Account', [addressesProvider]);
  console.log(`Account: ${address}`);
  return address;
}

// 6 step
async function setLeftAddressesToAddressesProvider(
  provider: string,
  account: string,
  aggregator: string,
) {
  const addressesProvider = await ethers.getContractAt('AddressesProvider', provider);

  const gasLimit1 = await addressesProvider.estimateGas.setAddress(
    ethers.utils.formatBytes32String('ACCOUNT'),
    account,
  );
  await addressesProvider.setAddress(ethers.utils.formatBytes32String('ACCOUNT'), account, {
    gasLimit: gasLimit1.add(gasLimit1.mul(BUMP_GAS_PRECENT).div(100)),
    ...defaultGasParams,
  });

  const gasLimit2 = await addressesProvider.estimateGas.setAddress(
    ethers.utils.formatBytes32String('FLASHLOAN_AGGREGATOR'),
    aggregator,
  );
  await addressesProvider.setAddress(ethers.utils.formatBytes32String('FLASHLOAN_AGGREGATOR'), aggregator, {
    gasLimit: gasLimit2.add(gasLimit2.mul(BUMP_GAS_PRECENT).div(100)),
    ...defaultGasParams,
  });
}

async function deployCreate2(expectedAddress: string, bytecode: BytesLike) {
  const code = await ethers.provider.getCode(expectedAddress, 'latest');

  // is contract return
  if (code && code !== '0x') {
    return;
  }
  const deployer = await ethers.getContractAt('SingletonFactory', EIP_DEPLOYER);
  const [sender] = await ethers.getSigners();

  try {
    console.log(`Deploying to (${expectedAddress})`);
    const tx = await deployer.connect(sender).deploy(bytecode, SALT, {
      gasLimit: DEFAULT_GAS_LIMIT,
      ...defaultGasParams,
    });
    await tx.wait(3);
  } catch (error) {
    console.error('Failed to deploy', error);
  }
}

async function getDeployByteCode(abi: any, bytecode: string, args: any[]) {
  let _bytecode = bytecode;

  if (args.length != 0) {
    const factory = new ethers.ContractFactory(abi, bytecode);
    const { data } = factory.getDeployTransaction(...args);

    if (!data) {
      throw new Error('Deploy transaction with no data. Something is very wrong');
    }

    _bytecode = data.toString();
  }

  return _bytecode;
}

export const buildBytecode = (constructorTypes: any[], constructorArgs: any[], contractBytecode: string) => {
  return `${contractBytecode}${encodeParams(constructorTypes, constructorArgs).slice(2)}`;
};

export const encodeParams = (dataTypes: any[], data: any[]) => {
  const abiCoder = ethers.utils.defaultAbiCoder;
  return abiCoder.encode(dataTypes, data);
};

export const getAddress = (bytecode: string) => {
  return `0x${ethers.utils
    .keccak256(
      `0x${['ff', EIP_DEPLOYER, SALT, ethers.utils.keccak256(bytecode)].map(x => x.replace(/0x/, '')).join('')}`,
    )
    .slice(-40)}`.toLowerCase();
};

async function _deploy(name: string, args: any[]) {
  const [sender] = await ethers.getSigners();
  console.log(`Deploying:${name}, args:${args}`);

  try {
    const factory = await ethers.getContractFactory(name);
    const contract = await factory.connect(sender).deploy(...args, {
      gasLimit: 2500000,
      ...defaultGasParams,
    });
    await contract.deployed();
    console.log(`Deployed ${name}:${contract.address}`);

    return contract.address;
  } catch (err) {
    console.log('error deploy', err);
    throw new Error('error deploy');
  }
}

update()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

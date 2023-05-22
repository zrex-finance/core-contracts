import { BytesLike } from 'ethers';
import { ethers, artifacts } from 'hardhat';

const EIP_DEPLOYER = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
const SALT = '0x0000000000000000000000000000000000000000000000000000004447441962';

const ACL_ADMIN = '0x1a5245ea5210C3B57B7Cfdf965990e63534A7b52';
const CONNECTOR_ADMIN = '0x1a5245ea5210C3B57B7Cfdf965990e63534A7b52';
const ROUTER_ADMIN = '0x1a5245ea5210C3B57B7Cfdf965990e63534A7b52'; // 0x0000076C91B41d2f872B9b061E75177E51CC1697

const TREASURY = '0x3E324D5C62762BCbC9203Ab624d6Cd5d5066d170';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const FEE = 3;
const BUMP_GAS_PRECENT = 130;
const DEFAULT_GAS_LIMIT = 2500000;

const defaultGasParams = {
  gasPrice: 180e9,
  // maxFeePerGas: 35e9,
  // maxPriorityFeePerGas: 3e9,
};

import routerArtifact from './artifacts/Router.json';
import configuratorArtifact from './artifacts/Configurator.json';
import addressProviderArtifact from './artifacts/AddressesProvider.json';

async function update() {
  const configurator = await ethers.getContractAt('Configurator', '0x1e4d2dE6a33394dA0e8A15218ad76c8Df3378733');

  await configurator.setFee('16', {
    ...defaultGasParams,
  });

  // const provider = await deployAddressesProvider();

  // const routerImpl = await deployRouter(provider);
  // const configuratorImpl = await deployConfigurator();

  // await setImplToAddressesProvider(provider, routerImpl, configuratorImpl); // get proxy addresses
}

async function deployAddressesProvider() {
  const bytecode = await getDeployByteCode(addressProviderArtifact.abi, addressProviderArtifact.bytecode, [
    ROUTER_ADMIN,
  ]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);

  // set acl admin, needed before deployed acl manager
  const addressesProvider = await ethers.getContractAt('AddressesProvider', expectedAddress);
  const aclAdmin = await addressesProvider.callStatic.getACLAdmin();

  if (aclAdmin === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('ACL_ADMIN'),
      ACL_ADMIN,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('ACL_ADMIN'), ACL_ADMIN, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
  console.log(`${addressProviderArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
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
    gasLimit: 100000,
    ...defaultGasParams,
  });

  const gasLimit2 = await addressesProvider.estimateGas.setConfiguratorImpl(configurator);
  const result = await addressesProvider.setConfiguratorImpl(configurator, {
    gasLimit: gasLimit2.add(gasLimit2.mul(BUMP_GAS_PRECENT).div(100)),
    ...defaultGasParams,
  });
  await result.wait(3);
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
async function setLeftAddressesToAddressesProvider(provider: string, account: string, aggregator: string) {
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

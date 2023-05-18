import { BytesLike } from 'ethers';
import { ethers, artifacts } from 'hardhat';

const EIP_DEPLOYER = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
const SALT = '0x0000000000000000000000000000000000000000000000000000004447441962';

const ACL_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697';
const CONNECTOR_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697';
const ROUTER_ADMIN = '0x0000076C91B41d2f872B9b061E75177E51CC1697'; // 0x0000076C91B41d2f872B9b061E75177E51CC1697

const TREASURY = '0x3E324D5C62762BCbC9203Ab624d6Cd5d5066d170';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const BUMP_GAS_PRECENT = 130;
const DEFAULT_GAS_LIMIT = 2500000;

const defaultGasParams = {
  gasPrice: 180e9
  // maxFeePerGas: 35e9,
  // maxPriorityFeePerGas: 3e9,
};

import proxyArtifact from './artifacts/Proxy.json';
import routerArtifact from './artifacts/Router.json';
import aclManagerArtifact from './artifacts/ACLManager.json';
import connectorsArtifact from './artifacts/Connectors.json';
import configuratorArtifact from './artifacts/Configurator.json';
import addressProviderArtifact from './artifacts/AddressesProvider.json';

async function deploy() {
  const provider = await deployAddressesProvider();

  const aclManager = await deployAclManager(provider);
  const connectors = await deployMainConnector(provider);
  await setAddressToAddressesProvider(provider, aclManager, connectors);

  const routerImpl = await deployRouter(provider);
  const configuratorImpl = await deployConfigurator();

  const configurator = await setImplToAddressesProvider(provider, routerImpl, configuratorImpl); // get proxy addresses

  await deployConnectors(configurator);

  const account = await deployAccount(provider);
  const proxy = await deployProxy(provider);

  await setLeftAddressesToAddressesProvider(provider, account, proxy);
}

// 1 step
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

// 2 step
async function deployAclManager(addressesProviderAddress: string) {
  const bytecode = await getDeployByteCode(aclManagerArtifact.abi, aclManagerArtifact.bytecode, [
    addressesProviderAddress,
  ]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);

  const aclManager = await ethers.getContractAt('ACLManager', expectedAddress);

  const isRouterAdmin = await aclManager.callStatic.isRouterAdmin(ROUTER_ADMIN);
  if (!isRouterAdmin) {
    const gasLimit = await aclManager.estimateGas.addRouterAdmin(ROUTER_ADMIN);
    await aclManager.addRouterAdmin(ROUTER_ADMIN, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }

  const isConnectorAdmin = await aclManager.callStatic.isConnectorAdmin(CONNECTOR_ADMIN);
  if (!isConnectorAdmin) {
    const gasLimit = await aclManager.estimateGas.addConnectorAdmin(CONNECTOR_ADMIN);
    await aclManager.addConnectorAdmin(CONNECTOR_ADMIN, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
  console.log(`${aclManagerArtifact.contractName}: ${expectedAddress}`);

  return expectedAddress;
}

// 3 step
async function deployMainConnector(addressesProviderAddress: string) {
  const bytecode = await getDeployByteCode(connectorsArtifact.abi, connectorsArtifact.bytecode, [
    addressesProviderAddress,
  ]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${connectorsArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

// 4 step
async function setAddressToAddressesProvider(provider: string, aclManager: string, connectors: string) {
  const addressesProvider = await ethers.getContractAt('AddressesProvider', provider);

  const aclManagerAddress = await addressesProvider.callStatic.getACLManager();
  if (aclManagerAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('ACL_MANAGER'),
      aclManager,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('ACL_MANAGER'), aclManager, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }

  const connectorsAddress = await addressesProvider.callStatic.getConnectors();
  if (connectorsAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('CONNECTORS'),
      connectors,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('CONNECTORS'), connectors, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
}

// 5 step
async function deployRouter(addressesProviderAddress: string) {
  const bytecode = await getDeployByteCode(routerArtifact.abi, routerArtifact.bytecode, [addressesProviderAddress]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${routerArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

// 6 step
async function deployConfigurator() {
  const bytecode = await getDeployByteCode(configuratorArtifact.abi, configuratorArtifact.bytecode, []);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${configuratorArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

// 7 step
async function setImplToAddressesProvider(provider: string, router: string, configurator: string) {
  const addressesProvider = await ethers.getContractAt('AddressesProvider', provider);

  const routerAddress = await addressesProvider.callStatic.getRouter();
  if (routerAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setRouterImpl(router);
    await addressesProvider.setRouterImpl(router, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }

  const configuratorAddress = await addressesProvider.callStatic.getConfigurator();
  if (configuratorAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setConfiguratorImpl(configurator);
    const result = await addressesProvider.setConfiguratorImpl(configurator, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
    await result.wait(3);
  }

  const configuratorProxy = await addressesProvider.callStatic.getConfigurator();

  if (configuratorProxy === ZERO_ADDRESS) {
    throw new Error('configurator proxy is 0x');
  }

  return configuratorProxy;
}

// 8 step
async function deployConnectors(configuratorAddress: string) {
  const connectors = [
    'contracts/connectors/polygon/AaveV2.sol:AaveV2Connector',
    'contracts/connectors/polygon/AaveV3.sol:AaveV3Connector',
    'CompoundV3Connector',
    'InchV5Connector',
    'UniswapConnector',
    'KyberV2Connector',
    'ParaSwapConnector',
    'AaveV2Flashloan',
    'AaveV3Flashloan',
    'BalancerFlashloan'
  ];
  const names = ['AaveV2', 'AaveV3', 'CompoundV3', 'OneInchV5', 'UniswapAuto', 'KyberV2', 'ParaSwap', 'AaveV2Flashloan', 'AaveV3Flashloan', 'BalancerFlashloan'];
  
  const addresses = [
    '0x87E82b4E7084F1f6F69775Caf104d81F78b2b335',
    '0xFA5f129591b58ad625a0450251951E7cd2847409',
    '0x0578746a6Ade6808C9Faf35C741F5dE4884d544F',
    '0xEC9831e9b29C0C65F99aE07464E52a12f8A41170',
    '0x1766C0CB1dDbD82EFe72A6Ab5f18aD92eb1ddCCd',
    '0xcde67DbD46DA8DAAE07301499f2f7349f231927C',
    '0x9F0aDe5cfD086144a2c0bc4BC14534B98a74Be4e',
    '0x7ecdc5DA73e3d5B97D1b7aF2a5AEe737a4eEcE9c',
    '0x8529807Ab32B0470fea76b70f752B011835eC05c',
    '0x3429E0637d9b32cd2Cc79fD77c491A7449582c7a'
  ];
  // let args: any[] = [];

  // for await (const name of connectors) {

  //   if (name == 'AaveV2Flashloan') {
  //     args = ['0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf', '0x7551b5D2763519d4e37e8B81929D336De671d46d']
  //   } else if (name == 'AaveV3Flashloan') {
  //     args = ['0x794a61358D6845594F94dc1DB02A252b5b4814aD', '0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654']
  //   } else  if (name == 'BalancerFlashloan') {
  //     args = ['0xBA12222222228d8Ba445958a75a0704d566BF2C8']
  //   }

  //   const address = await _deploy(name, args);
  //   console.log(`${name}: ${address}`);
  //   addresses.push(address);
  // }

  const configurator = await ethers.getContractAt('Configurator', configuratorAddress);
  // @ts-ignore
  await configurator.addConnectors(names, addresses);
}

// 9 step
async function deployAccount(addressesProvider: string) {
  const address = await _deploy('Account', [addressesProvider]);
  console.log(`Account: ${address}`);
  return address;
}

// 10 step
async function deployProxy(addressesProvider: string) {
  const bytecode = await getDeployByteCode(proxyArtifact.abi, proxyArtifact.bytecode, [addressesProvider]);
  const expectedAddress = getAddress(bytecode);

  // deploy contracts
  await deployCreate2(expectedAddress, bytecode);
  console.log(`${proxyArtifact.contractName}: ${expectedAddress}`);
  return expectedAddress;
}

// 11 step
async function setLeftAddressesToAddressesProvider(
  provider: string,
  account: string,
  proxy: string
) {
  const addressesProvider = await ethers.getContractAt('AddressesProvider', provider);

  const accountAddress = await addressesProvider.callStatic.getAccountImpl();
  if (accountAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('ACCOUNT'),
      account,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('ACCOUNT'), account, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
  const treasuryAddress = await addressesProvider.callStatic.getTreasury();
  if (treasuryAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('TREASURY'),
      TREASURY,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('TREASURY'), TREASURY, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
  const proxyAddress = await addressesProvider.callStatic.getAccountProxy();
  if (proxyAddress === ZERO_ADDRESS) {
    const gasLimit = await addressesProvider.estimateGas.setAddress(
      ethers.utils.formatBytes32String('ACCOUNT_PROXY'),
      proxy,
    );
    await addressesProvider.setAddress(ethers.utils.formatBytes32String('ACCOUNT_PROXY'), proxy, {
      gasLimit: gasLimit.add(gasLimit.mul(BUMP_GAS_PRECENT).div(100)),
      ...defaultGasParams,
    });
  }
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

deploy()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

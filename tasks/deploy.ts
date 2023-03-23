import { BytesLike } from "ethers";
import { ethers } from "hardhat";

const EIP_DEPLOYER = '0xce0042B868300000d44A59004Da54A005ffdcf9f'
const SALT = "0x0000000000000000000000000000000000000000000000000000000047941987"

const ACL_ADMIN = "0x444444Cc7FE267251797d8592C3f4d5EE6888D62"
const CONNECTOR_ADMIN = "0x444444Cc7FE267251797d8592C3f4d5EE6888D62"
const ROUTER_ADMIN = "0x444444Cc7FE267251797d8592C3f4d5EE6888D62"

const TREASURY = "0x444444Cc7FE267251797d8592C3f4d5EE6888D62"
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

const FEE = 3;

async function deploy() {
    const provider = await deployAddressesProvider();

    const aclManager = await deployAclManager(provider);
    const connectors = await deployMainConnector(provider);
    await setAddressToAddressesProvider(provider, aclManager, connectors);

    const routerImpl = await deployRouter(provider);
    const configuratorImpl = await deployConfigurator();

    const configurator = await setImplToAddressesProvider(provider, routerImpl, configuratorImpl); // get proxy addresses

    await deployConnectors(configurator);

    const flashAggregator = await deployFlashAggregator();
    await deployFlashResolver(flashAggregator);

    const account = await deployAccount(provider);
    const proxy = await deployProxy(provider);

    await setLeftAddressesToAddressesProvider(provider, account, proxy, flashAggregator);

    await setFee(configurator);
}

// 1 step
async function deployAddressesProvider() {
    const bytecode = await getDeployByteCode("AddressesProvider", []);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    // set acl admin, needed before deployed acl manager
    const addressesProvider = await ethers.getContractAt("AddressesProvider", expectedAddress);
    const aclAdmin = await addressesProvider.callStatic.getACLAdmin();

    if (aclAdmin === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("ACL_ADMIN"), ACL_ADMIN);
    }

    return expectedAddress;
}

// 2 step
async function deployAclManager(addressesProviderAddress: string) {
    const bytecode = await getDeployByteCode("ACLManager", [addressesProviderAddress]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    const aclManager = await ethers.getContractAt("ACLManager", expectedAddress);

    const isRouterAdmin = await aclManager.callStatic.isRouterAdmin(ROUTER_ADMIN);
    if (!isRouterAdmin) {
        await aclManager.addRouterAdmin(ROUTER_ADMIN);
    }

    const isConnectorAdmin = await aclManager.callStatic.isConnectorAdmin(CONNECTOR_ADMIN);
    if (!isConnectorAdmin) {
        await aclManager.addConnectorAdmin(CONNECTOR_ADMIN);
    }

    return expectedAddress
}

// 3 step
async function deployMainConnector(addressesProviderAddress: string) {
    const bytecode = await getDeployByteCode("Connectors", [addressesProviderAddress]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 4 step 
async function setAddressToAddressesProvider(provider: string, aclManager: string, connectors: string) {
    const addressesProvider = await ethers.getContractAt("AddressesProvider", provider);

    const aclManagerAddress = await addressesProvider.callStatic.getACLManager();
    if (aclManagerAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("ACL_MANAGER"), aclManager);
    }

    const connectorsAddress = await addressesProvider.callStatic.getConnectors();
    if (connectorsAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("CONNECTORS"), connectors);
    }
}

// 5 step
async function deployRouter(addressesProviderAddress: string) {
    const bytecode = await getDeployByteCode("Router", [addressesProviderAddress]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 6 step
async function deployConfigurator() {
    const bytecode = await getDeployByteCode("Configurator", []);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 7 step
async function setImplToAddressesProvider(provider: string, router: string, configurator: string) {
    const addressesProvider = await ethers.getContractAt("AddressesProvider", provider);

    const routerAddress = await addressesProvider.callStatic.getRouter();
    if (routerAddress === ZERO_ADDRESS) {
        await addressesProvider.setRouterImpl(router);
    }

    const configuratorAddress = await addressesProvider.callStatic.getConfigurator();
    if (configuratorAddress === ZERO_ADDRESS) {
        await addressesProvider.setConfiguratorImpl(configurator);
    }

    const configuratorProxy = await addressesProvider.callStatic.getConfigurator();

    return configuratorProxy
}

// 8 step 
async function deployConnectors(configuratorAddress: string) {
    const connectors = ["AaveV2Connector","AaveV3Connector","CompoundV2Connector","CompoundV3Connector","InchV5Connector","UniswapConnector"]
    const names = ["AaveV2", "AaveV3", "CompoundV2", "CompoundV3", "OneInchV5", "UniswapAuto"];
    const addresses = [];

    for await (const connector of connectors) {
        const bytecode = await getDeployByteCode(connector, []);
        const expectedAddress = getAddress(bytecode)
        await deployCreate2(expectedAddress, bytecode);
        addresses.unshift(expectedAddress);
    }

    const configurator = await ethers.getContractAt("Configurator", configuratorAddress);
    await configurator.addConnectors(names, addresses);
}

// 9 step
async function deployFlashAggregator() {
    const bytecode = await getDeployByteCode("FlashAggregator", []);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 10 step
async function deployFlashResolver(flashAggregatorAddress: string) {
    const bytecode = await getDeployByteCode("FlashResolver", [flashAggregatorAddress]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);
}

// 11 step
async function deployAccount(addressesProvider: string) {
    const bytecode = await getDeployByteCode("Account", [addressesProvider]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 12 step
async function deployProxy(addressesProvider: string) {
    const bytecode = await getDeployByteCode("Proxy", [addressesProvider]);
    const expectedAddress = getAddress(bytecode);

    // deploy contracts
    await deployCreate2(expectedAddress, bytecode);

    return expectedAddress
}

// 13 step
async function setLeftAddressesToAddressesProvider(
    provider: string,
    account: string, 
    proxy: string,
    aggregator: string
) {
    const addressesProvider = await ethers.getContractAt("AddressesProvider", provider);

    const accountAddress = await addressesProvider.callStatic.getAccountImpl();
    if (accountAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("ACCOUNT"), account);
    }
    const treasuryAddress = await addressesProvider.callStatic.getTreasury();
    if (treasuryAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("TREASURY"), TREASURY);
    }
    const proxyAddress = await addressesProvider.callStatic.getAccountProxy();
    if (proxyAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("ACCOUNT_PROXY"), proxy);
    }
    const aggregatorAddress = await addressesProvider.callStatic.getFlashloanAggregator();
    if (aggregatorAddress === ZERO_ADDRESS) {
        await addressesProvider.setAddress(ethers.utils.formatBytes32String("FLASHLOAN_AGGREGATOR"), aggregator);
    }
}

// 14 step
async function setFee(configuratorAddress: string) {
    const configurator = await ethers.getContractAt("Configurator", configuratorAddress);
    await configurator.setFee(FEE);
}

async function deployCreate2(expectedAddress: string, bytecode: BytesLike) {
    const code = await ethers.provider.getCode(expectedAddress, 'latest')

    // is contract return
    if (code && code !== '0x') {
       return
    }
    const deployer = await ethers.getContractAt("SingeltonFactory", EIP_DEPLOYER);

    try {
        console.log(`Deploying to (${expectedAddress})`)
        const tx = await deployer.deploy(bytecode, SALT, { gasLimit: 7_000_000, gasPrice: 15e9 })
        await tx.wait()
    } catch {
        console.error('Failed to deploy')
    }
}

function getAddress(bytecode: BytesLike) {
    const initHash = ethers.utils.keccak256(bytecode)
    return ethers.utils.getCreate2Address(EIP_DEPLOYER, SALT, initHash)
  }

async function getDeployByteCode(contractName: string, args: any[]) {
    const factory = await ethers.getContractFactory(contractName)
    const bytecode = factory.getDeployTransaction(...args).data

    if (!bytecode) {
        throw new Error("Unvalid bytecode");
    }

    return bytecode
}

deploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

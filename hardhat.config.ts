import fs from "fs";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
import "hardhat-tracer";
import "hardhat-gas-reporter";
import "hardhat-preprocessor";
import { HardhatUserConfig, task } from "hardhat/config";
import { config as dotEnvConfig } from "dotenv";

function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean)
        .map(line => line.trim().split("="));
}

dotEnvConfig();

const { INFURA_TOKEN, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    paths: {
        sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
        cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
    },
    networks: {
        goerli: {
            url: `https://goerli.infura.io/v3/${INFURA_TOKEN}`,
            accounts: PRIVATE_KEY
                ? [PRIVATE_KEY]
                : {
                      mnemonic: "test test test test test test test test test test test junk",
                  },
        },
        mainnet: {
            url: `https://mainnet.infura.io/v3/${INFURA_TOKEN}`,
            accounts: PRIVATE_KEY
                ? [PRIVATE_KEY]
                : {
                      mnemonic: "test test test test test test test test test test test junk",
                  },
        },
        hardhat: {
            blockGasLimit: 9500000,
            chainId: 1,
            forking: {
                url: `https://eth-mainnet.alchemyapi.io/v2/qPC1XAgnhOiR3kuhw9DJ8g8WVLWs6R9Q`,
                blockNumber: 16241092,
            },
            initialBaseFeePerGas: 5,
        },
        coverage: {
            url: "http://127.0.0.1:8555",
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    mocha: {
        timeout: 100000000,
    },
    // This fully resolves paths for imports in the ./lib directory for Hardhat
    preprocess: {
        eachLine: hre => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    getRemappings().forEach(([find, replace]) => {
                        if (line.match(find)) {
                            line = line.replace(find, replace);
                        }
                    });
                }
                return line;
            },
        }),
    },
};

export default config;

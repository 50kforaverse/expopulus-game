import "hardhat-etherscan-abi";
// import "@nomiclabs/hardhat-waffle";
import "@xyrusworx/hardhat-solidity-json";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";
import 'hardhat-watcher'

require("@nomicfoundation/hardhat-chai-matchers")

import { HardhatUserConfig } from "hardhat/config";

// for testing only
const mnemonic = "major ostrich lake feed mean term sort essay claw catch deal toddler naive subject inmate";

const accounts = {
  count: 10,
  initialIndex: 0,
  mnemonic,
  path: "m/44'/60'/0'/0",
};

export const config: HardhatUserConfig & any = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts,
      chainId: 43114,
      blockGasLimit: 30000000,
    }
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  watcher: {
    test: {
      tasks: ['test'],
      files: ['./contracts', './test'],
    },
  },
  gasReporter: {
    enabled: false,
  },
  solidity: {
    compilers: [
      { version: "0.8.20", settings: {} },
      { version: "0.8.12", settings: {} },
      { version: "0.8.9", settings: {} },
      { version: "0.8.0", settings: {} },
      { version: "0.6.2", settings: {} },
    ],
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: "none",
      },
      // You should disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 1, // https://docs.soliditylang.org/en/v0.8.9/internals/optimizer.html#optimizer-parameter-runs
      },
    },
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;

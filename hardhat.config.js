require('hardhat-deploy');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-etherscan');
require('@openzeppelin/hardhat-upgrades');
require('solidity-coverage');
require('hardhat-contract-sizer');
require('hardhat-gas-reporter');

require('dotenv').config();

const { INFURA_PROJECT_ID } = process.env;
const { DEPLOYER_PRIVATE_KEY } = process.env;

if (!process.env.GAS_PRICE) {
  throw new Error('Must provide GAS_PRICE e.g. export GAS_PRICE=5500000000');
}

const args = process.argv.slice(2);

let etherScanApiKey;
let gasPrice;

if (args.includes('mumbai')) {
  etherScanApiKey = process.env.MUMBAI_ETHERSCAN_API_KEY;
  gasPrice = parseInt(process.env.MUMBAI_GAS_PRICE, 10);
} else if (args.includes('rinkeby')) {
  etherScanApiKey = process.env.RINKEBY_ETHERSCAN_API_KEY;
  gasPrice = parseInt(process.env.RINKEBY_GAS_PRICE, 10);
} else if (args.includes('mainnet')) {
  etherScanApiKey = process.env.MAINNET_ETHERSCAN_API_KEY;
  gasPrice = parseInt(process.env.MAINNET_GAS_PRICE, 10);
} else if (args.includes('matic')) {
  etherScanApiKey = process.env.MATIC_ETHERSCAN_API_KEY;
  gasPrice = parseInt(process.env.MATIC_GAS_PRICE, 10);
} else {
  throw new Error(`Could not get network from args! ${args.join(', ')}`);
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.3',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
    },
    localhost: {
      url: `http://127.0.0.1:8545`,
      network_id: '*',
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_PROJECT_ID}`,
      chainId: 4,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
    bsc_testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
      chainId: 1,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
    matic: {
      url: `https://polygon-mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
      chainId: 137,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${INFURA_PROJECT_ID}`,
      chainId: 80001,
      // url: `https://matic-mumbai.chainstacklabs.com/`,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
    arb_rinkeby: {
      url: 'https://rinkeby.arbitrum.io/rpc',
      chainId: 42161,
      gasPrice,
      ...(DEPLOYER_PRIVATE_KEY
        ? { accounts: [`0x${DEPLOYER_PRIVATE_KEY}`] }
        : {}),
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: etherScanApiKey,
  },
  contractSizer: {
    alphaSort: false,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    governor: {
      default: 0,
    },
  },
  gasReporter: {
    coinmarketcap: process.env.COIN_MARKET_CAP_API_KEY,
    currency: 'EUR',
    enabled: true,
  },
};

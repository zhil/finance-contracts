const hre = require('hardhat');

const { deployUpgradableContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  let uniswapRouter;

  switch (hre && hre.hardhatArguments && hre.hardhatArguments.network) {
    case 'mainnet':
      uniswapRouter = process.env.MAINNET_UNISWAP_ROUTER_ADDR;
      break;
    case 'rinkeby':
      uniswapRouter = process.env.RINKEBY_UNISWAP_ROUTER_ADDR;
      break;
    case 'matic':
      uniswapRouter = process.env.MATIC_UNISWAP_ROUTER_ADDR;
      break;
    case 'mumbai':
      uniswapRouter = process.env.MUMBAI_UNISWAP_ROUTER_ADDR;
      break;
    case 'hardhat':
      uniswapRouter = process.env.RINKEBY_UNISWAP_ROUTER_ADDR;
      break;
    default:
      throw new Error(`Could not resolve Uniswap Router address.`);
  }

  await deployUpgradableContract(deployments, deployer, governor, 'Treasury', [
    uniswapRouter,
  ]);
};

module.exports.tags = ['Treasury'];

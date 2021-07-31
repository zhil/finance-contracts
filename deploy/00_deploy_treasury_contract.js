const {deployUpgradableContract} = require('../hardhat.util');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer, governor} = await getNamedAccounts();

  await deployUpgradableContract(deployments, deployer, governor, 'Treasury', [
    process.env.UNISWAP_ROUTER_ADDR,
  ]);
};

module.exports.tags = ['Treasury'];

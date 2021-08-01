const {deployPermanentContract} = require('../hardhat.util');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer, governor} = await getNamedAccounts();

  await deployPermanentContract(deployments, deployer, governor, 'ProxyRegistry', []);
};

module.exports.tags = ['ProxyRegistry'];

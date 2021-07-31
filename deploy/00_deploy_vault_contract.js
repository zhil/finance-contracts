const {deployUpgradableContract} = require('../hardhat.util');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer, governor} = await getNamedAccounts();

  await deployUpgradableContract(deployments, deployer, governor, 'Vault', []);
};

module.exports.tags = ['Vault'];

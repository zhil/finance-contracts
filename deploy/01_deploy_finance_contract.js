const web3 = require('web3');

const {deployUpgradableContract} = require('../hardhat.util');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer, governor} = await getNamedAccounts();

  const token = await deployments.get('Token');
  const treasury = await deployments.get('Treasury');

  const contractArguments = [
    // TODO
  ];

  await deployUpgradableContract(deployments, deployer, governor, 'FlairFinance', contractArguments);
};

module.exports.tags = ['FlairFinance'];
module.exports.dependencies = ['Token', 'Treasury', 'Vault'];

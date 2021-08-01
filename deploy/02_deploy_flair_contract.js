const web3 = require('web3');

const {deployUpgradableContract} = require('../hardhat.util');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer, governor} = await getNamedAccounts();

  const treasury = await deployments.get('Treasury');
  const funding = await deployments.get('Funding');

  const contractArguments = [
    treasury.address,
    funding.address,
    500, // protocolFee: 5%
  ];

  await deployUpgradableContract(deployments, deployer, governor, 'Flair', contractArguments);
};

module.exports.tags = ['Flair'];
module.exports.dependencies = ['Token', 'Treasury', 'Funding'];

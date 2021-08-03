const web3 = require('web3');

const { deployUpgradableContract, deployPermanentContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  const treasury = await deployments.get('Treasury');
  const funding = await deployments.get('Funding');
  const registry = await deployments.get('Registry');

  const contractArguments = [
    [registry.address],
    treasury.address,
    funding.address,
    500, // protocolFee: 5%
  ];

  await deployUpgradableContract(
    deployments,
    deployer,
    governor,
    'Flair',
    contractArguments
  );

  await deployPermanentContract(
    deployments,
    deployer,
    governor,
    'TestERC721',
    []
  );
};

module.exports.tags = ['Flair'];
module.exports.dependencies = ['Token', 'Treasury', 'Funding'];

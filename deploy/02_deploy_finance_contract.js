const { deployUpgradableContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  const treasury = await deployments.get('Treasury');
  const funding = await deployments.get('Funding');
  const registry = await deployments.get('Registry');

  const contractArguments = [
    [registry.address],
    treasury.address,
    funding.address,
    100, // protocolFee: 1%
  ];

  await deployUpgradableContract(
    deployments,
    deployer,
    governor,
    'Finance',
    contractArguments
  );
};

module.exports.tags = ['Finance'];
module.exports.dependencies = ['Token', 'Treasury', 'Funding'];

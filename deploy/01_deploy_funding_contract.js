const { deployUpgradableContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  const token = await deployments.get('Token');

  const contractArguments = [
    token.address,
    1000000, // rewardRatio (Bancor Reserve Weight): 1
  ];

  await deployUpgradableContract(
    deployments,
    deployer,
    governor,
    'Funding',
    contractArguments
  );
};

module.exports.tags = ['Funding'];
module.exports.dependencies = ['Token'];

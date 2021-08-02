const { deployPermanentContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  await deployPermanentContract(
    deployments,
    deployer,
    governor,
    'StaticValidators',
    []
  );
};

module.exports.tags = ['StaticValidators'];

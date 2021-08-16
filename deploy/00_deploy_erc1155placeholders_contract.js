const { deployPermanentContract } = require('../hardhat.util');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, governor } = await getNamedAccounts();

  await deployPermanentContract(
    deployments,
    deployer,
    governor,
    'ERC1155Placeholders',
    ['ipfs://']
  );
};

module.exports.tags = ['ERC1155Placeholders'];

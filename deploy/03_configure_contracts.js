const web3 = require('web3');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();

  const flair = await deployments.get('Flair');

  await deployments.execute(
    'Registry',
    { from: deployer },
    'grantInitialAuthentication',
    flair.address
  );
};

module.exports.tags = ['configure'];
module.exports.dependencies = [];

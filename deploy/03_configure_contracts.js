const web3 = require('web3');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();

  const flair = await deployments.get('Flair');
  const funding = await deployments.get('Funding');

  await deployments.execute(
    'Registry',
    { from: deployer },
    'grantInitialAuthentication',
    flair.address
  );

  await deployments.execute(
    'Token',
    { from: deployer },
    'grantRole',
    web3.utils.soliditySha3('MINTER_ROLE'),
    funding.address
  );

  await deployments.execute(
    'Funding',
    { from: deployer },
    'grantRole',
    web3.utils.soliditySha3('ORCHESTRATOR_ROLE'),
    flair.address
  );
};

module.exports.tags = ['configure'];
module.exports.dependencies = [];

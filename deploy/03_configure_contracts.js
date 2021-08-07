const web3 = require('web3');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();

  const finance = await deployments.get('Finance');
  const funding = await deployments.get('Funding');

  try {
    await deployments.execute(
      'Registry',
      { from: deployer },
      'grantInitialAuthentication',
      finance.address
    );
  } catch (e) {
    console.warn('Could not grantInitialAuthentication! Perhaps already done?');
  }

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
    finance.address
  );
};

module.exports.tags = ['configure'];
module.exports.dependencies = [];

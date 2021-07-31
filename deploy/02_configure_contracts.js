const web3 = require('web3');

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer} = await getNamedAccounts();

  const token = await deployments.get('Token');
  const flairFinance = await deployments.get('FlairFinance');

  // TODO
};

module.exports.tags = ['configure'];
module.exports.dependencies = [];

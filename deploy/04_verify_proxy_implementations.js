const hre = require('hardhat');

module.exports = async ({ deployments }) => {
  if (
    !hre.hardhatArguments ||
    !hre.hardhatArguments.network ||
    hre.hardhatArguments.network === 'hardhat' ||
    hre.hardhatArguments.network.substr(0, 4) === 'bsc_'
  ) {
    console.log(` - skipping verification on ${hre.hardhatArguments.network}.`);
    return;
  }

  const finance = await deployments.get('Finance');
  const registry = await deployments.get('Registry');
  const token = await deployments.get('Token');
  const treasury = await deployments.get('Treasury');
  const staticValidators = await deployments.get('StaticValidators');

  for (const contract of [
    finance,
    registry,
    token,
    treasury,
    staticValidators,
  ]) {
    try {
      if (contract.implementation) {
        await hre.run('verify:verify', {
          address: contract.implementation,
        });
      } else if (contract.address) {
        await hre.run('verify:verify', {
          address: contract.address,
        });
      }
    } catch (err) {
      if (
        !err.toString().includes('already verified') &&
        !err.toString().includes('could not be found')
      ) {
        throw err;
      }
    }
  }
};

module.exports.tags = ['verify'];
module.exports.dependencies = [];

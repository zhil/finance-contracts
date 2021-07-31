const hre = require('hardhat');

module.exports = async ({deployments}) => {
  if (
    !hre.hardhatArguments ||
    !hre.hardhatArguments.network ||
    hre.hardhatArguments.network === 'hardhat' ||
    hre.hardhatArguments.network.substr(0, 4) === 'bsc_'
  ) {
    console.log(` - skipping verification on ${hre.hardhatArguments.network}.`);
    return;
  }

  const token = await deployments.get('Token');
  const vault = await deployments.get('Vault');
  const treasury = await deployments.get('Treasury');
  const marketer = await deployments.get('Marketer');
  const directory = await deployments.get('Directory');

  for (const contract of [directory, marketer, token, vault, treasury]) {
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
      if (!err.toString().includes('already verified')) {
        throw err;
      }
    }
  }
};

module.exports.tags = ['verify'];
module.exports.dependencies = [];

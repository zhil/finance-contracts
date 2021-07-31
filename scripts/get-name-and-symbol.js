const hre = require("hardhat");

if (!process.env.HARDHAT_NETWORK) {
  throw new Error('Must provide HARDHAT_NETWORK env');
}

async function main() {
  const result = await hre.deployments.read(
    'Token',
    'name',
  );

  console.log('Result: ', result);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

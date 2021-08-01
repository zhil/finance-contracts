const web3 = require('web3');

const setupTest = deployments.createFixture(
  async (
    { deployments, getNamedAccounts, getUnnamedAccounts, ethers },
    options
  ) => {
    const governor = (await getNamedAccounts()).deployer;
    const accounts = await getUnnamedAccounts();

    await deployments.fixture();

    return {
      governor: {
        signer: await ethers.getSigner(governor),
        flairContract: await ethers.getContract('Flair', governor),
        tokenContract: await ethers.getContract('Token', governor),
        treasuryContract: await ethers.getContract('Treasury', governor),
        registryContract: await ethers.getContract('ProxyRegistry', governor),
        fundingContract: await ethers.getContract('Funding', governor),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          governor
        ),
      },
      userA: {
        signer: await ethers.getSigner(accounts[0]),
        flairContract: await ethers.getContract('Flair', accounts[0]),
        tokenContract: await ethers.getContract('Token', accounts[0]),
        treasuryContract: await ethers.getContract('Treasury', accounts[0]),
        registryContract: await ethers.getContract(
          'ProxyRegistry',
          accounts[0]
        ),
        fundingContract: await ethers.getContract('Funding', accounts[0]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[0]
        ),
      },
      userB: {
        signer: await ethers.getSigner(accounts[1]),
        flairContract: await ethers.getContract('Flair', accounts[1]),
        tokenContract: await ethers.getContract('Token', accounts[1]),
        treasuryContract: await ethers.getContract('Treasury', accounts[1]),
        registryContract: await ethers.getContract(
          'ProxyRegistry',
          accounts[1]
        ),
        fundingContract: await ethers.getContract('Funding', accounts[1]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[1]
        ),
      },
      userC: {
        signer: await ethers.getSigner(accounts[2]),
        flairContract: await ethers.getContract('Flair', accounts[2]),
        tokenContract: await ethers.getContract('Token', accounts[2]),
        treasuryContract: await ethers.getContract('Treasury', accounts[2]),
        registryContract: await ethers.getContract(
          'ProxyRegistry',
          accounts[2]
        ),
        fundingContract: await ethers.getContract('Funding', accounts[2]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[2]
        ),
      },
      userD: {
        signer: await ethers.getSigner(accounts[3]),
        flairContract: await ethers.getContract('Flair', accounts[3]),
        tokenContract: await ethers.getContract('Token', accounts[3]),
        treasuryContract: await ethers.getContract('Treasury', accounts[3]),
        registryContract: await ethers.getContract(
          'ProxyRegistry',
          accounts[3]
        ),
        fundingContract: await ethers.getContract('Funding', accounts[3]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[3]
        ),
      },
      userE: {
        signer: await ethers.getSigner(accounts[4]),
        flairContract: await ethers.getContract('Flair', accounts[4]),
        tokenContract: await ethers.getContract('Token', accounts[4]),
        treasuryContract: await ethers.getContract('Treasury', accounts[4]),
        registryContract: await ethers.getContract(
          'ProxyRegistry',
          accounts[4]
        ),
        fundingContract: await ethers.getContract('Funding', accounts[4]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[4]
        ),
      },
    };
  }
);

module.exports = {
  setupTest,
};

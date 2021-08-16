const web3 = require('web3');
const { deployPermanentContract } = require('../hardhat.util');

const setupTest = deployments.createFixture(
  async (
    { deployments, getNamedAccounts, getUnnamedAccounts, ethers },
    options
  ) => {
    const governor = (await getNamedAccounts()).deployer;
    const accounts = await getUnnamedAccounts();

    await deployments.fixture();

    await deployPermanentContract(
      deployments,
      governor,
      governor,
      'TestERC721',
      []
    );

    return {
      governor: {
        signer: await ethers.getSigner(governor),
        financeContract: await ethers.getContract('Finance', governor),
        tokenContract: await ethers.getContract('Token', governor),
        treasuryContract: await ethers.getContract('Treasury', governor),
        registryContract: await ethers.getContract('Registry', governor),
        fundingContract: await ethers.getContract('Funding', governor),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          governor
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          governor
        ),
        testERC721: await ethers.getContract('TestERC721', governor),
      },
      userA: {
        signer: await ethers.getSigner(accounts[0]),
        financeContract: await ethers.getContract('Finance', accounts[0]),
        tokenContract: await ethers.getContract('Token', accounts[0]),
        treasuryContract: await ethers.getContract('Treasury', accounts[0]),
        registryContract: await ethers.getContract('Registry', accounts[0]),
        fundingContract: await ethers.getContract('Funding', accounts[0]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[0]
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          accounts[0]
        ),
        testERC721: await ethers.getContract('TestERC721', accounts[0]),
      },
      userB: {
        signer: await ethers.getSigner(accounts[1]),
        financeContract: await ethers.getContract('Finance', accounts[1]),
        tokenContract: await ethers.getContract('Token', accounts[1]),
        treasuryContract: await ethers.getContract('Treasury', accounts[1]),
        registryContract: await ethers.getContract('Registry', accounts[1]),
        fundingContract: await ethers.getContract('Funding', accounts[1]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[1]
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          accounts[1]
        ),
        testERC721: await ethers.getContract('TestERC721', accounts[1]),
      },
      userC: {
        signer: await ethers.getSigner(accounts[2]),
        financeContract: await ethers.getContract('Finance', accounts[2]),
        tokenContract: await ethers.getContract('Token', accounts[2]),
        treasuryContract: await ethers.getContract('Treasury', accounts[2]),
        registryContract: await ethers.getContract('Registry', accounts[2]),
        fundingContract: await ethers.getContract('Funding', accounts[2]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[2]
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          accounts[2]
        ),
        testERC721: await ethers.getContract('TestERC721', accounts[2]),
      },
      userD: {
        signer: await ethers.getSigner(accounts[3]),
        financeContract: await ethers.getContract('Finance', accounts[3]),
        tokenContract: await ethers.getContract('Token', accounts[3]),
        treasuryContract: await ethers.getContract('Treasury', accounts[3]),
        registryContract: await ethers.getContract('Registry', accounts[3]),
        fundingContract: await ethers.getContract('Funding', accounts[3]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[3]
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          accounts[3]
        ),
        testERC721: await ethers.getContract('TestERC721', accounts[3]),
      },
      userE: {
        signer: await ethers.getSigner(accounts[4]),
        financeContract: await ethers.getContract('Finance', accounts[4]),
        tokenContract: await ethers.getContract('Token', accounts[4]),
        treasuryContract: await ethers.getContract('Treasury', accounts[4]),
        registryContract: await ethers.getContract('Registry', accounts[4]),
        fundingContract: await ethers.getContract('Funding', accounts[4]),
        staticValidators: await ethers.getContract(
          'StaticValidators',
          accounts[4]
        ),
        erc1155Placeholders: await ethers.getContract(
          'ERC1155Placeholders',
          accounts[4]
        ),
        testERC721: await ethers.getContract('TestERC721', accounts[4]),
      },
    };
  }
);

module.exports = {
  setupTest,
};

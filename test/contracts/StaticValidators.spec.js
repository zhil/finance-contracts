const { expect } = require('chai');
const web3 = require('web3');

const { setupTest } = require('../setup');

describe('StaticValidators', () => {
  const web3Instance = new web3(web3.currentProvider);

  it('should accept return of multiple tokens from Flair ERC721 scaffold', async () => {
    const { userA, userB } = await setupTest();

    const extraData = web3Instance.eth.abi.encodeParameters(
      ['address'],
      [userA.testERC721.address.toLowerCase()]
    );

    const callSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'transferFromBulk(address,address,uint256[])'
    );
    const callData = web3Instance.eth.abi.encodeParameters(
      ['address', 'address', 'uint256[]'],
      [
        userB.signer.address.toLowerCase(),
        userA.signer.address.toLowerCase(),
        ['555', '666', '777'],
      ]
    );

    const newFill = await userA.staticValidators.acceptReturnERC721Bulk(
      // (address erc721Contract)
      extraData,
      // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
      [
        userA.signer.address.toLowerCase(),
        userA.registryContract.address.toLowerCase(),
        userA.signer.address.toLowerCase(),
        userA.testERC721.address.toLowerCase(),
        userB.signer.address.toLowerCase(),
      ],
      // howToCall
      '0',
      // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
      ['0', '1000', '162341912', '0', '15'],
      // call data
      `${callSelector}${callData.substr(2)}`
    );

    expect(newFill).to.equal(12);
  });
});
